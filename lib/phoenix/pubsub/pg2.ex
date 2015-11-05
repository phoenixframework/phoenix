defmodule Phoenix.PubSub.PG2 do
  use Supervisor

  @moduledoc """
  Phoenix PubSub adapter based on PG2.

  To use it as your PubSub adapter, simply add it to your Endpoint's config:

      config :my_app, MyApp.Endpoint,
        pubsub: [adapter: Phoenix.PubSub.PG2]

  ## Options

    * `:name` - The name to register the PubSub processes, ie: `MyApp.PubSub`
    * `:pool_size` - Both the size of the local pubsub server pool and subscriber
      shard size. Defaults `1`. A single pool is often enough for most use-cases,
      but for high subscriber counts on a single topic or greater than 1M
      clients, a pool size equal to the number of schedulers (cores) is a well
      rounded size.

  """

  def start_link(name, opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, opts], name: supervisor_name)
  end

  @doc false
  def init([server, opts]) do
    pool_size = Keyword.fetch!(opts, :pool_size)
    dispatch_rules = [{:broadcast, Phoenix.PubSub.PG2Server, [server, pool_size]}]

    children = [
      supervisor(Phoenix.PubSub.LocalSupervisor, [server, pool_size, dispatch_rules]),
      worker(Phoenix.PubSub.PG2Server, [server]),
    ]

    supervise children, strategy: :rest_for_one
  end
end
