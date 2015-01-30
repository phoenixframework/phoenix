defmodule Phoenix.PubSub.Redis do
  use Supervisor

  @moduledoc false

  @pool_size 5

  def start_link(opts) do
    supervisor_name = Module.concat(__MODULE__, Keyword.fetch!(opts, :name))
    Supervisor.start_link(__MODULE__, opts, name: supervisor_name)
  end

  def init(opts) do
    server_name = Keyword.fetch!(opts, :name)
    local_name  = Module.concat(server_name, Local)
    pool_name   = Module.concat(server_name, Pool)
    server_opts = Keyword.merge(opts, local_name: local_name,
                                      pool_name: pool_name)

    pool_opts = [
      name: {:local, pool_name},
      worker_module: Phoenix.PubSub.RedisBroadcaster,
      size: opts[:pool_size] || @pool_size,
      max_overflow: 0
    ]

    children = [
      worker(Phoenix.PubSub.Local, [local_name], restart: :transient),
      worker(Phoenix.PubSub.RedisServer, [server_opts], restart: :transient),
      :poolboy.child_spec(pool_name, pool_opts, [server_opts]),
    ]
    supervise children, strategy: :one_for_all
  end
end
