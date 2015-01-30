defmodule Phoenix.PubSub.Redis do
  use Supervisor

  @moduledoc """
  The Supervisor for the Redis `Phoenix.PubSub` adapter

  To use Redis as your PubSub adapter, simply add it to your application's
  supervision tree:

      children = [
        ...
        worker(...),
        supervisor(Phoenix.PubSub.Redis, [[name: MyApp.PubSub]]),
      ]

  and add `:eredis` to your deps:

      defp deps do
        [{:eredis, github: "wooga/eredis"},
        ...
      end


  ## Options

    * `name` - The required name to register the PubSub processes, ie: `MyApp.PubSub`
    * `host` - The redis-server host IP, defaults `"127.0.0.1"`
    * `port` - The redis-server port, defaults `6379`
    * `password` - The redis-server password, defaults `""`

  """
  def start_link(opts) do
    supervisor_name = Module.concat(__MODULE__, Keyword.fetch!(opts, :name))
    Supervisor.start_link(__MODULE__, opts, name: supervisor_name)
  end

  @doc false
  def init(opts) do
    server_name = Keyword.fetch!(opts, :name)
    local_name  = Module.concat(server_name, Local)
    server_opts = Keyword.merge(opts, local_name: local_name)

    children = [
      worker(Phoenix.PubSub.Local, [local_name], restart: :transient),
      worker(Phoenix.PubSub.RedisServer, [server_opts], restart: :transient),
    ]
    supervise children, strategy: :one_for_all
  end
end
