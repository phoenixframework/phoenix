defmodule Phoenix.Integration.DepsCompiler.CacheServer do
  @moduledoc false

  alias Phoenix.Integration.CodeGeneratorCase

  use GenServer

  def start_link(opts) when is_list(opts) do
    {start_opts, server_opts} = Keyword.split(opts, [:name])

    hash = Keyword.fetch!(server_opts, :hash)
    cache_root_path = Keyword.fetch!(server_opts, :cache_root_path)

    GenServer.start_link(__MODULE__, %{hash: hash, cache_root_path: cache_root_path}, start_opts)
  end

  def compile_or_restore(server, app_root_path, timeout \\ 90_000) do
    case GenServer.call(server, {:maybe_compile, app_root_path}, timeout) do
      :compiled ->
        :ok

      {:cache_hit, cache_path} ->
        File.cp_r!(
          cache_path,
          app_root_path
        )

        File.cp_r!(
          Path.join([app_root_path, "_build", "dev"]),
          Path.join([app_root_path, "_build", "test"])
        )

        :ok
    end
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:maybe_compile, app_root_path}, _from, state) do
    build_cache_with_hash_path = Path.join([state.cache_root_path, "build", state.hash])

    if File.dir?(build_cache_with_hash_path) do
      {:reply, {:cache_hit, build_cache_with_hash_path}, state}
    else
      CodeGeneratorCase.mix_run!(["deps.compile"], app_root_path)

      File.mkdir_p!(build_cache_with_hash_path)

      # Using the system's copy command with -rL to expand the symbolic links in the
      # rebar compiled dependencies. Rebar compiles its dependencies in deps/ and
      # symlinks them into _build/. This means if we restored the cache to a new project
      # and left the symlinks to deps in tact, the rebar-based dependencies would have to be
      # recompiled because their compiled code would be missing.
      {_output, 0} =
        System.cmd("cp", [
          "-rL",
          Path.join(app_root_path, "_build"),
          build_cache_with_hash_path
        ])

      {:reply, :compiled, state}
    end
  end
end
