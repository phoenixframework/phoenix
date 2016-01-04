# The GenServer used by the CodeReloader.
defmodule Phoenix.CodeReloader.Server do
  @moduledoc false
  use GenServer

  require Logger
  alias Phoenix.CodeReloader.Proxy

  def start_link(app, paths, compilers, opts \\ []) do
    GenServer.start_link(__MODULE__, {app, paths, compilers}, opts)
  end

  def reload!(endpoint) do
    children = Supervisor.which_children(endpoint)

    case List.keyfind(children, __MODULE__, 0) do
      {__MODULE__, pid, _, _} ->
        case GenServer.call(pid, :reload!, :infinity) do
          {:raise, error} -> raise error
          other -> other
        end
      _ ->
        raise "Code reloader was invoked for #{inspect endpoint} but no code reloader " <>
              "server was started. Be sure to move `plug Phoenix.CodeReloader` inside " <>
              "a `if code_reloading? do` block in your endpoint"
    end
  end

  ## Callbacks

  def init({app, paths, compilers}) do
    all = Mix.Project.config[:compilers] || Mix.compilers
    compilers = all -- (all -- compilers)
    {:ok, {app, paths, compilers}}
  end

  def handle_call(:reload!, from, {app, paths, compilers} = state) do
    froms = all_waiting([from])
    reply = mix_compile(Code.ensure_loaded(Mix.Task), app, paths, compilers)
    Enum.each(froms, &GenServer.reply(&1, reply))
    {:noreply, state}
  end

  defp all_waiting(acc) do
    receive do
      {:"$gen_call", from, :reload!} -> all_waiting([from | acc])
    after
      0 -> acc
    end
  end

  defp mix_compile({:error, _reason}, _, _, _) do
    message = "If you want to use the code reload plug in production or " <>
              "inside an escript, add :mix to your list of dependencies or " <>
              "disable code reloading"
    {:raise, RuntimeError.exception(message)}
  end

  defp mix_compile({:module, Mix.Task}, app, paths, compilers) do
    if Mix.Project.umbrella? do
      dep = Enum.find Mix.Dep.Umbrella.loaded, &(&1.app == app)
      Mix.Dep.in_dependency(dep, fn _ ->
        mix_compile_unless_stale_config(paths, compilers)
      end)
    else
      mix_compile_unless_stale_config(paths, compilers)
    end
  end

  defp mix_compile_unless_stale_config(paths, compilers) do
    manifests = Mix.Tasks.Compile.Elixir.manifests
    all_paths = Mix.Project.config[:elixirc_paths]

    others  = Mix.Utils.extract_files(all_paths -- paths, [:ex])
    configs = Mix.Project.config_files

    case Mix.Utils.extract_stale(others ++ configs, manifests) do
      [] ->
        mix_compile(paths, compilers)
      files ->
        message = """
        you must restart your server after changing the following config or lib files:

          * #{Enum.map_join(files, "\n  * ", &Path.relative_to_cwd/1)}
        """
        {:raise, RuntimeError.exception(message)}
    end
  end

  defp mix_compile(paths, compilers) do
    opts = Enum.flat_map(paths, &["--elixirc-paths", &1])
    Enum.each compilers, &Mix.Task.reenable("compile.#{&1}")

    {res, out} =
      proxy_io(fn ->
        try do
          # We call build_structure mostly for Windows so any
          # new assets in priv is copied to the build directory.
          Mix.Project.build_structure
          res = Enum.flat_map(compilers, &mix_compile_each(&1, opts))

          if :ok in res && consolidate_protocols? do
            Mix.Task.reenable("compile.protocols")
            mix_compile_each("protocols", [])
          else
            res
          end
        catch
          _, _ -> :error
        end
      end)

    cond do
      :error in res -> {:error, out}
      :ok in res    -> :ok
      true          -> :noop
    end
  end

  defp mix_compile_each(compiler, opts) do
    # We always wrap in a list because Mix.Task.run
    # will return a list in case of umbrella applications.
    List.wrap(Mix.Task.run("compile.#{compiler}", opts))
  end

  defp consolidate_protocols? do
    Mix.Project.config[:consolidate_protocols]
  end

  defp proxy_io(fun) do
    original_gl = Process.group_leader
    {:ok, proxy_gl} = Proxy.start()
    Process.group_leader(self(), proxy_gl)

    try do
      res = fun.()
      {List.wrap(res), Proxy.stop(proxy_gl)}
    after
      Process.group_leader(self(), original_gl)
      Process.exit(proxy_gl, :kill)
    end
  end
end
