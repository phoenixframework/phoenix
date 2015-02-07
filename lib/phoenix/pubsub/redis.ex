defmodule Phoenix.PubSub.Redis do
  use Supervisor

  @moduledoc """
  The Supervisor for the Redis `Phoenix.PubSub` adapter

  To use Redis as your PubSub adapter, simply add it to your Endpoint's config:

      config :my_app, MyApp.Endpiont,
        ...
        pubsub: [adapter: Phoenix.PubSub.Redis,
                 options: [host: "192.168.1.100"]


  next, add `:eredis`, and `:poolboy` to your deps:

      defp deps do
        [{:eredis, github: "wooga/eredis"},
         {:poolboy, "~> 1.4.2"},
        ...]
      end

  finally, add `:poolboy` to your applications:

      def application do
        [mod: {MyApp, []},
         applications: [..., :phoenix, :poolboy],
         ...]
      end



    * `name` - The required name to register the PubSub processes, ie: `MyApp.PubSub`
    * `opts` - The optional redis options:
      * `host` - The redis-server host IP, defaults `"127.0.0.1"`
      * `port` - The redis-server port, defaults `6379`
      * `password` - The redis-server password, defaults `""`

  """

  @pool_size 5
  @defaults [host: "127.0.0.1", port: 6379, password: ""]


  def start_link(name, opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, [name, opts], name: supervisor_name)
  end

  @doc false
  def init([server_name, opts]) do
    opts = Keyword.merge(@defaults, opts)
    opts = Keyword.merge(opts, host: String.to_char_list(to_string(opts[:host])),
                               password: String.to_char_list(to_string(opts[:password])))

    pool_name   = Module.concat(server_name, Pool)
    local_name  = Module.concat(server_name, Local)
    server_opts = Keyword.merge(opts, name: server_name,
                                      local_name: local_name,
                                      pool_name: pool_name)
    pool_opts = [
      name: {:local, pool_name},
      worker_module: Phoenix.PubSub.RedisConn,
      size: opts[:pool_size] || @pool_size,
      max_overflow: 0
    ]

    children = [
      worker(Phoenix.PubSub.Local, [local_name]),
      :poolboy.child_spec(pool_name, pool_opts, [opts]),
      worker(Phoenix.PubSub.RedisServer, [server_opts]),
    ]
    supervise children, strategy: :one_for_all
  end
end
