# The GenServer used by the CodeReloader.
defmodule Phoenix.CodeReloader.Server do
  @moduledoc false
  use GenServer

  require Logger
  alias Phoenix.CodeReloader.Proxy

  def start_link(app, compilers, opts \\ []) do
    GenServer.start_link(__MODULE__, {app, compilers}, opts)
  end

  def reload!(endpoint) do
    children = Supervisor.which_children(endpoint)

    case List.keyfind(children, __MODULE__, 0) do
      {__MODULE__, pid, _, _} ->
        GenServer.call(pid, :reload!, :infinity)
      _ ->
        raise "Code reloader was invoked for #{inspect endpoint} but no code reloader " <>
              "server was started. Be sure to move `plug Phoenix.CodeReloader` inside " <>
              "a `if code_reloading? do` block in your endpoint"
    end
  end

  ## Callbacks

  def init({app, compilers}) do
    all = Mix.Project.config[:compilers] || Mix.compilers
    compilers = all -- (all -- compilers)
    {:ok, {app, compilers}}
  end

  def handle_call(:reload!, from, {app, compilers} = state) do
    froms = all_waiting([from])

    {res, out} =
      proxy_io(fn ->
        try do
          mix_compile(Code.ensure_loaded(Mix.Task), app, compilers)
        catch
          :exit, {:shutdown, 1} ->
            :error
          kind, reason ->
            IO.puts Exception.format(kind, reason, System.stacktrace)
            :error
        end
      end)

    reply =
      case res do
        :ok    -> :ok
        :error -> {:error, out}
      end

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

  defp mix_compile({:error, _reason}, _, _) do
    raise "the Code Reloader is enabled but Mix is not available. If you want to " <>
          "use the Code Reloader in production or inside an escript, you must add " <>
          ":mix to your applications list. Otherwise, you must disable code reloading " <>
          "in such environments"
  end

  defp mix_compile({:module, Mix.Task}, _app, compilers) do
    if Mix.Project.umbrella? do
      Enum.each Mix.Dep.Umbrella.loaded, fn dep ->
        Mix.Dep.in_dependency(dep, fn _ ->
          mix_compile_unless_stale_config(compilers)
        end)
      end
    else
      mix_compile_unless_stale_config(compilers)
      :ok
    end
  end

  defp mix_compile_unless_stale_config(compilers) do
    manifests = Mix.Tasks.Compile.Elixir.manifests
    configs   = Mix.Project.config_files

    case Mix.Utils.extract_stale(configs, manifests) do
      [] ->
        mix_compile(compilers)
      files ->
        raise """
        could not compile application: #{Mix.Project.config[:app]}.

        You must restart your server after changing the following config or lib files:

          * #{Enum.map_join(files, "\n  * ", &Path.relative_to_cwd/1)}
        """
     end
   end

  defp mix_compile(compilers) do
    Enum.each compilers, &Mix.Task.reenable("compile.#{&1}")

    # We call build_structure mostly for Windows so new
    # assets in priv are copied to the build directory.
    Mix.Project.build_structure
    res = Enum.map(compilers, &Mix.Task.run("compile.#{&1}", []))

    if :ok in res && consolidate_protocols?() do
      Mix.Task.reenable("compile.protocols")
      Mix.Task.run("compile.protocols", [])
    end

    res
  end

  defp consolidate_protocols? do
    Mix.Project.config[:consolidate_protocols]
  end

  defp proxy_io(fun) do
    original_gl = Process.group_leader
    {:ok, proxy_gl} = Proxy.start()
    Process.group_leader(self(), proxy_gl)

    try do
      {fun.(), Proxy.stop(proxy_gl)}
    after
      Process.group_leader(self(), original_gl)
      Process.exit(proxy_gl, :kill)
    end
  end
end
