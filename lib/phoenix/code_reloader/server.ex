defmodule Phoenix.CodeReloader.Server do
  @moduledoc false
  use GenServer

  require Logger
  alias Phoenix.CodeReloader.Proxy

  def start_link() do
    GenServer.start_link(__MODULE__, false, name: __MODULE__)
  end

  def check_symlinks do
    GenServer.call(__MODULE__, :check_symlinks, :infinity)
  end

  def reload!(endpoint) do
    GenServer.call(__MODULE__, {:reload!, endpoint}, :infinity)
  end

  ## Callbacks

  def init(false) do
    {:ok, false}
  end

  def handle_call(:check_symlinks, _from, checked?) do
    if not checked? and Code.ensure_loaded?(Mix.Project) and not Mix.Project.umbrella? do
      priv_path = "#{Mix.Project.app_path}/priv"

      case :file.read_link(priv_path) do
        {:ok, _} ->
          :ok

        {:error, _} ->
          if can_symlink?() do
            File.rm_rf(priv_path)
            Mix.Project.build_structure
          else
            Logger.warn "Phoenix is unable to create symlinks. Phoenix' code reloader will run " <>
                        "considerably faster if symlinks are allowed." <> os_symlink(:os.type)
          end
      end
    end

    {:reply, :ok, true}
  end

  def handle_call({:reload!, endpoint}, from, state) do
    compilers = endpoint.config(:reloadable_compilers)
    backup = load_backup(endpoint)
    froms  = all_waiting([from], endpoint)

    {res, out} =
      proxy_io(fn ->
        try do
          mix_compile(Code.ensure_loaded(Mix.Task), compilers)
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
        :ok ->
          :ok
        :error ->
          write_backup(backup)
          {:error, out}
      end

    Enum.each(froms, &GenServer.reply(&1, reply))
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp os_symlink({:win32, _}),
    do: " On Windows, the lack of symlinks may even cause empty assets to be served. " <>
        "Luckily, you can address this issue by starting your Windows terminal at least " <>
        "once with \"Run as Administrator\" and then running your Phoenix application."
  defp os_symlink(_),
    do: ""

  defp can_symlink?() do
    build_path = Mix.Project.build_path()
    symlink = Path.join(Path.dirname(build_path), "__phoenix__")

    case File.ln_s(build_path, symlink) do
      :ok ->
        File.rm_rf(symlink)
        true

      {:error, :eexist} ->
        File.rm_rf(symlink)
        true

      {:error, _} ->
        false
    end
  end

  defp load_backup(mod) do
    mod
    |> :code.which()
    |> read_backup()
  end
  defp read_backup(path) when is_list(path) do
    case File.read(path) do
      {:ok, binary} -> {:ok, path, binary}
      _ -> :error
    end
  end
  defp read_backup(_path), do: :error

  defp write_backup({:ok, path, file}), do: File.write!(path, file)
  defp write_backup(:error), do: :ok

  defp all_waiting(acc, endpoint) do
    receive do
      {:"$gen_call", from, {:reload!, ^endpoint}} -> all_waiting([from | acc], endpoint)
    after
      0 -> acc
    end
  end

  # TODO: Remove the function_exported call after 1.3 support is removed
  # and just use loaded. apply/3 is used to prevent a compilation
  # warning.
  defp mix_compile({:module, Mix.Task}, compilers) do
    if Mix.Project.umbrella? do
      deps =
        if function_exported?(Mix.Dep.Umbrella, :cached, 0) do
          apply(Mix.Dep.Umbrella, :cached, [])
        else
          Mix.Dep.Umbrella.loaded
        end
      Enum.each deps, fn dep ->
        Mix.Dep.in_dependency(dep, fn _ ->
          mix_compile_unless_stale_config(compilers)
        end)
      end
    else
      mix_compile_unless_stale_config(compilers)
      :ok
    end
  end
  defp mix_compile({:error, _reason}, _) do
    raise "the Code Reloader is enabled but Mix is not available. If you want to " <>
          "use the Code Reloader in production or inside an escript, you must add " <>
          ":mix to your applications list. Otherwise, you must disable code reloading " <>
          "in such environments"
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
    all = Mix.Project.config[:compilers] || Mix.compilers

    compilers =
      for compiler <- compilers, compiler in all do
        Mix.Task.reenable("compile.#{compiler}")
        compiler
      end

    # We call build_structure mostly for Windows so new
    # assets in priv are copied to the build directory.
    Mix.Project.build_structure
    results = Enum.map(compilers, &Mix.Task.run("compile.#{&1}", []))

    # Results are either {:ok, _} | {:error, _}, {:noop, _} or
    # :ok | :error | :noop. So we use proplists to do the unwraping.
    cond do
      :proplists.get_value(:error, results, false) ->
        exit({:shutdown, 1})

      :proplists.get_value(:ok, results, false) && consolidate_protocols?() ->
        Mix.Task.reenable("compile.protocols")
        Mix.Task.run("compile.protocols", [])
        :ok

      true ->
        :ok
    end
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
