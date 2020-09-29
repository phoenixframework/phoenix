defmodule Phoenix.Integration.DepsCompiler do
  @moduledoc false

  @instance __MODULE__
  @registry_instance __MODULE__.Registry
  @cache_supervisor_instance __MODULE__.CacheSupervisor

  alias Phoenix.Integration.DepsCompiler.CacheServer

  def start_link do
    Supervisor.start_link(
      [
        {Registry, keys: :unique, name: @registry_instance},
        {DynamicSupervisor, name: @cache_supervisor_instance, strategy: :one_for_one}
      ],
      strategy: :rest_for_one,
      name: @instance
    )
  end

  def compile_deps(app_root_path) do
    app_root_path
    |> Path.join("mix.lock")
    |> calculate_file_hash()
    |> get_cache_server()
    |> CacheServer.compile_or_restore(app_root_path)

    :ok
  end

  defp get_cache_server(mix_lock_hash) do
    DynamicSupervisor.start_child(
      @cache_supervisor_instance,
      {CacheServer, [
          hash: mix_lock_hash,
          cache_root_path: cache_root_path(),
          name: cache_server_instance_name(mix_lock_hash)
        ]}
    )
    |> case do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  defp cache_server_instance_name(mix_lock_hash) do
    {:via, Registry, {@registry_instance, mix_lock_hash}}
  end

  defp cache_root_path do
    Path.expand("../../tmp/integration_cache", __DIR__)
  end

  defp calculate_file_hash(path) do
    file_contents = File.read!(path)

    :crypto.hash(:sha256, file_contents)
    |> Base.encode16(case: :lower)
  end
end
