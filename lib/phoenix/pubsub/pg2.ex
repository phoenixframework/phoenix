defmodule Phoenix.PubSub.PG2 do
  use Supervisor

  @moduledoc """
  The Supervisor for the `:pg2` `Phoenix.PubSub` adapter

  To use PG2 as your PubSub adapter, simply add it to your application's
  supervision tree:

      children = [
        ...
        worker(...),
        supervisor(Phoenix.PubSub.PG2, [[name: MyApp.PubSub]]),
      ]

  ## Options

    * `name` - The required name to register the PubSub processes, ie: `MyApp.PubSub`

  """

  def start_link(opts) do
    supervisor_name = Module.concat(Keyword.fetch!(opts, :name), Supervisor)
    Supervisor.start_link(__MODULE__, opts, name: supervisor_name)
  end

  @doc false
  def init(opts) do
    server_name = Keyword.fetch!(opts, :name)
    local_name  = Module.concat(server_name, Local)
    server_opts = Keyword.put(opts, :local_name, local_name)

    children = [
      worker(Phoenix.PubSub.Local, [local_name], restart: :transient),
      worker(Phoenix.PubSub.PG2Server, [server_opts], restart: :transient),
    ]
    supervise children, strategy: :one_for_all
  end
end
