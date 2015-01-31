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


    * `name` - The required name to register the PubSub processes, ie: `MyApp.PubSub`
    * `opts` - The optional redis options:
      * `host` - The redis-server host IP, defaults `"127.0.0.1"`
      * `port` - The redis-server port, defaults `6379`
      * `password` - The redis-server password, defaults `""`

  """
  def start_link(name, opts \\ []) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, opts], name: supervisor_name)
  end

  @doc false
  def init([server_name, opts]) do
    local_name  = Module.concat(server_name, Local)
    server_opts = Keyword.merge(opts, name: server_name, local_name: local_name)

    children = [
      worker(Phoenix.PubSub.Local, [local_name]),
      worker(Phoenix.PubSub.RedisServer, [server_opts]),
    ]
    supervise children, strategy: :one_for_all
  end
end
