defmodule Phoenix.PubSub.RedisSupervisor do
  use Supervisor

  @moduledoc false

  @pool_size 5

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    pool_opts = [
      name: {:local, :phx_redis_pool},
      worker_module: Phoenix.PubSub.RedisBroadcaster,
      size: opts[:pool_size] || @pool_size,
      max_overflow: 0
    ]

    children = [
      worker(Phoenix.PubSub.RedisServer, [opts]),
      :poolboy.child_spec(:phx_redis_pool, pool_opts, [opts])
    ]
    supervise children, strategy: :one_for_one
  end
end
