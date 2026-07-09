defmodule Phoenix.CodeReloader.Server do
  @moduledoc false
  use GenServer

  # Elixir v1.19 bundles consolidation into compile.elixir
  # so we no longer need to trigger it manually
  @requires_consolidation not Version.match?(System.version(), ">= 1.19.0")

  require Logger
  alias Phoenix.CodeReloader.Proxy

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def check_symlinks do
    GenServer.call(__MODULE__, :check_symlinks, :infinity)
  end

  def reload!(endpoint, opts) do
    GenServer.call(__MODULE__, {:reload!, endpoint, opts}, :infinity)
  end

  def sync do
    pid = Process.whereis(__MODULE__)
    ref = Process.monitor(pid)
    GenServer.cast(pid, {:sync, self(), ref})

    receive do
      ^ref -> :ok
      {:DOWN, ^ref, _, _, _} -> :ok
    end
  end

  ## Callbacks

  def init(:ok) do
    # The Elixir compiler does not check to see if the mix.lock is stale during
    # compilation as that's effectively handled on boot.
    #
    # On boot, Elixir checks if all dependencies match the lock. If they don't,
    # Elixir fails to boot, and force a "mix deps.get". Which then writes a
    # .mix/compile.lock checked by the Elixir compiler.
    #
    # Meanwhile, Phoenix has to answer the question: has the lock file changed?
    # The usual answer is to compare configuration files to the Elixir manifest
    # but we can't do that for the lockfile because touching the lockfile does
    # not necessarily force Elixir to compile. As established above, the lockfile
    # is checked on boot and it does not use timestamps for said checks. We could
    # compare .mix/compile.lock but, since Elixir v1.20, changing .mix/compile.lock
    # does not force Elixir to compile either. Generally speaking, the smarter the
    # compiler gets, the harder it is to predict when it requires compilation.
    # For this reason, we do a simple system where we compare config files and their
    # MD5 to the latest timestamp and we abort if any of them changed.
    md5s =
      if Code.ensure_loaded?(Mix.Project) do
        config = Mix.Project.config()
        build_path = Mix.Project.build_path(config)

        for file <- [config[:lockfile] | Mix.Project.config_files()],
            # We only care about config files in the project,
            # as we don't want track internal manifest files (per the comment above)
            # and because reporting internal files to the user is a poor UX.
            not String.starts_with?(file, build_path),
            do: {file, file_md5(file)}
      else
        %{}
      end

    {:ok, %{check_symlinks: true, timestamp: timestamp(), md5s: md5s}}
  end

  defp file_md5(file) do
    case File.read(file) do
      {:ok, content} -> :erlang.md5(content)
      {:error, _} -> nil
    end
  end

  def handle_call(:check_symlinks, _from, state) do
    if state.check_symlinks and Code.ensure_loaded?(Mix.Project) and not Mix.Project.umbrella?() and
         File.dir?("priv") do
      priv_path = "#{Mix.Project.app_path()}/priv"

      case :file.read_link(priv_path) do
        {:ok, _} ->
          :ok

        {:error, _} ->
          if can_symlink?() do
            File.rm_rf(priv_path)
            Mix.Project.build_structure()
          else
            Logger.warning(
              "Phoenix is unable to create symlinks. Phoenix's code reloader will run " <>
                "considerably faster if symlinks are allowed." <> os_symlink(:os.type())
            )
          end
      end
    end

    {:reply, :ok, %{state | check_symlinks: false}}
  end

  def handle_call({:reload!, endpoint, opts}, from, state) do
    compilers = endpoint.config(:reloadable_compilers)
    apps = endpoint.config(:reloadable_apps) || default_reloadable_apps()
    args = Keyword.get(opts, :reloadable_args, ["--no-all-warnings"])

    froms = all_waiting([from], endpoint)

    {backup, res, out} =
      with_build_lock(fn ->
        purge_fallback? =
          if Phoenix.CodeReloader.MixListener.started?() do
            Phoenix.CodeReloader.MixListener.purge(apps)
            false
          else
            warn_missing_mix_listener()
            true
          end

        # We do a backup of the endpoint in case compilation fails.
        # If so we can bring it back to finish the request handling.
        backup = load_backup(endpoint)

        {res, out} =
          proxy_io(fn ->
            try do
              task_loaded = Code.ensure_loaded(Mix.Task)
              mix_compile(task_loaded, compilers, apps, args, purge_fallback?, state)
            catch
              :exit, {:shutdown, 1} ->
                :error

              kind, reason ->
                IO.puts(Exception.format(kind, reason, __STACKTRACE__))
                :error
            end
          end)

        {backup, res, out}
      end)

    {reply, state} =
      case res do
        :ok ->
          {:ok, %{state | timestamp: timestamp()}}

        :error ->
          write_backup(backup)
          {{:error, IO.iodata_to_binary(out)}, state}
      end

    Enum.each(froms, &GenServer.reply(&1, reply))
    {:noreply, state}
  end

  def handle_cast({:sync, pid, ref}, state) do
    send(pid, ref)
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp default_reloadable_apps() do
    if Mix.Project.umbrella?() do
      Enum.map(Mix.Dep.Umbrella.cached(), & &1.app)
    else
      [Mix.Project.config()[:app]]
    end
  end

  defp os_symlink({:win32, _}),
    do:
      " On Windows, the lack of symlinks may even cause empty assets to be served. " <>
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
      {:"$gen_call", from, {:reload!, ^endpoint, _}} -> all_waiting([from | acc], endpoint)
    after
      0 -> acc
    end
  end

  if Version.match?(System.version(), ">= 1.18.0-dev") do
    defp warn_missing_mix_listener do
      if Mix.Project.get() != Phoenix.MixProject do
        IO.warn("""
        a Mix listener expected by Phoenix.CodeReloader is missing.

        Please add the listener to your mix.exs configuration, like so:

            def project do
              [
                ...,
                listeners: [Phoenix.CodeReloader]
              ]
            end

        """)
      end
    end
  else
    defp warn_missing_mix_listener do
      :ok
    end
  end

  defp mix_compile(
         {:module, Mix.Task},
         compilers,
         apps_to_reload,
         compile_args,
         purge_fallback?,
         state
       ) do
    timestamp = state.timestamp
    config = Mix.Project.config()
    path = Mix.Project.consolidation_path(config)

    state.md5s
    |> Enum.filter(fn {file, md5} ->
      Mix.Utils.stale?([file], [timestamp]) and file_md5(file) != md5
    end)
    |> Enum.map(&elem(&1, 0))
    |> raise_if_config_files_changed()

    mix_compile_deps(
      Mix.Dep.cached(),
      apps_to_reload,
      compile_args,
      compilers,
      timestamp,
      path,
      purge_fallback?
    )

    mix_compile_project(
      config[:app],
      apps_to_reload,
      compile_args,
      compilers,
      timestamp,
      path,
      purge_fallback?
    )

    if @requires_consolidation && config[:consolidate_protocols] do
      # If we are consolidating protocols, we need to purge all of its modules
      # to ensure the consolidated versions are loaded. "mix compile" performs
      # a similar task.
      Code.prepend_path(path)
      purge_modules(path)
    end

    :ok
  end

  defp mix_compile({:error, _reason}, _, _, _, _, _) do
    raise "the Code Reloader is enabled but Mix is not available. If you want to " <>
            "use the Code Reloader in production or inside an escript, you must add " <>
            ":mix to your applications list. Otherwise, you must disable code reloading " <>
            "in such environments"
  end

  defp mix_compile_deps(
         deps,
         apps_to_reload,
         compile_args,
         compilers,
         timestamp,
         path,
         purge_fallback?
       ) do
    for dep <- deps, dep.app in apps_to_reload do
      Mix.Dep.in_dependency(dep, fn _ ->
        mix_compile_unless_stale_config(compilers, compile_args, timestamp, path, purge_fallback?)
      end)
    end
  end

  defp mix_compile_project(nil, _, _, _, _, _, _), do: :ok

  defp mix_compile_project(
         app,
         apps_to_reload,
         compile_args,
         compilers,
         timestamp,
         path,
         purge_fallback?
       ) do
    if app in apps_to_reload do
      mix_compile_unless_stale_config(compilers, compile_args, timestamp, path, purge_fallback?)
    end
  end

  defp mix_compile_unless_stale_config(compilers, compile_args, timestamp, path, purge_fallback?) do
    manifests = Mix.Tasks.Compile.Elixir.manifests()
    config = Mix.Project.config()

    # TODO: remove once we depend on Elixir 1.18
    if purge_fallback? and Mix.Utils.stale?(manifests, [timestamp]) do
      purge_modules(Path.join(Mix.Project.app_path(config), "ebin"))
    end

    mix_compile(compilers, compile_args, config, path)
  end

  defp raise_if_config_files_changed([]) do
    :ok
  end

  defp raise_if_config_files_changed(files) do
    raise """
    could not compile application: #{Mix.Project.config()[:app]}.

    You must restart your server after changing configuration files or your dependencies.
    In particular, the following files changed and must be recomputed on a server restart:

      * #{Enum.map_join(files, "\n  * ", &Path.relative_to_cwd/1)}

    """
  end

  defp mix_compile(compilers, compile_args, config, consolidation_path) do
    all = config[:compilers] || Mix.compilers()

    compilers =
      for compiler <- compilers, compiler in all do
        Mix.Task.reenable("compile.#{compiler}")
        compiler
      end

    # We call build_structure mostly for Windows so new
    # assets in priv are copied to the build directory.
    Mix.Project.build_structure(config)

    args = [
      "--purge-consolidation-path-if-stale",
      consolidation_path,
      # Since Elixir v1.20, Elixir no longer automatically purges compiler
      # modules, which is ok for most workflows, but since code reloading never
      # shuts down the server, we enable purging to avoid too many temp modules.
      "--purge-compiler-modules" | compile_args
    ]

    {status, diagnostics} =
      with_logger_app(config, fn ->
        run_compilers(compilers, args, :noop, [])
      end)

    Proxy.diagnostics(Process.group_leader(), diagnostics)

    cond do
      status == :error ->
        if "--return-errors" not in args do
          exit({:shutdown, 1})
        end

      @requires_consolidation && status == :ok && config[:consolidate_protocols] ->
        # TODO: Calling compile.protocols is no longer be required from Elixir v1.19
        Mix.Task.reenable("compile.protocols")
        Mix.Task.run("compile.protocols", [])
        :ok

      true ->
        :ok
    end
  end

  defp timestamp, do: System.system_time(:second)

  defp purge_modules(path) do
    with {:ok, beams} <- File.ls(path) do
      for beam <- beams do
        case :binary.split(beam, ".beam") do
          [module, ""] -> module |> String.to_atom() |> purge_module()
          _ -> :ok
        end
      end

      :ok
    end
  end

  defp purge_module(module) do
    :code.purge(module)
    :code.delete(module)
  end

  defp proxy_io(fun) do
    original_gl = Process.group_leader()
    {:ok, proxy_gl} = Proxy.start()
    Process.group_leader(self(), proxy_gl)

    try do
      {fun.(), Proxy.stop(proxy_gl)}
    after
      Process.group_leader(self(), original_gl)
      Process.exit(proxy_gl, :kill)
    end
  end

  ## TODO: Replace this by Mix.Task.Compiler.run/2 on Elixir v1.19+

  defp run_compilers([], _, status, diagnostics) do
    {status, diagnostics}
  end

  defp run_compilers([compiler | rest], args, status, diagnostics) do
    {new_status, new_diagnostics} = run_compiler(compiler, args)
    diagnostics = diagnostics ++ new_diagnostics

    case new_status do
      :error -> {:error, diagnostics}
      :ok -> run_compilers(rest, args, :ok, diagnostics)
      :noop -> run_compilers(rest, args, status, diagnostics)
    end
  end

  defp run_compiler(compiler, args) do
    result = normalize(Mix.Task.run("compile.#{compiler}", args), compiler)
    Enum.reduce(Mix.ProjectStack.pop_after_compiler(compiler), result, & &1.(&2))
  end

  defp normalize(result, name) do
    case result do
      {status, diagnostics} when status in [:ok, :noop, :error] and is_list(diagnostics) ->
        {status, diagnostics}

      # ok/noop can come from tasks that have already run
      _ when result in [:ok, :noop] ->
        {result, []}

      _ ->
        # TODO: Convert this to an error on v2.0
        Mix.shell().error(
          "warning: Mix compiler #{inspect(name)} was supposed to return " <>
            "{:ok | :noop | :error, [diagnostic]} but it returned #{inspect(result)}"
        )

        {:noop, []}
    end
  end

  # TODO: remove once we depend on Elixir 1.17
  defp with_logger_app(config, fun) do
    app = Keyword.fetch!(config, :app)
    logger_config_app = Application.get_env(:logger, :compile_time_application)

    try do
      Logger.configure(compile_time_application: app)
      fun.()
    after
      Logger.configure(compile_time_application: logger_config_app)
    end
  end

  # TODO: remove once we depend on Elixir 1.18
  if Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :with_build_lock, 1) do
    defp with_build_lock(fun), do: Mix.Project.with_build_lock(fun)
  else
    defp with_build_lock(fun), do: fun.()
  end
end
