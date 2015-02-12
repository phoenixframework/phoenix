defmodule Phoenix.PubSub.PG2 do
  use Supervisor

  @moduledoc """
  The Supervisor for the `:pg2` `Phoenix.PubSub` adapter

  To use PG2 as your PubSub adapter, simply add it to your Endpoint's config:

      config :my_app, MyApp.Endpiont,
        ...
        pubsub: [adapter: Phoenix.PubSub.PG2]



    * `name` - The required name to register the PubSub processes, ie: `MyApp.PubSub`

  """

  def start_link(name, _opts) do
    supervisor_name = Module.concat(name, Supervisor)
    Supervisor.start_link(__MODULE__, name, name: supervisor_name)
  end

  @doc false
  def init(server_name) do
    local_name = Module.concat(server_name, Local)

    children = [
      worker(Phoenix.PubSub.Local, [local_name]),
      worker(Phoenix.PubSub.PG2Server, [[name: server_name, local_name: local_name]]),
    ]
    supervise children, strategy: :rest_for_one
  end
end
