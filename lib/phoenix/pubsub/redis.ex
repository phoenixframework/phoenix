defmodule Phoenix.PubSub.Redis do
  use Supervisor

  @moduledoc false

  def start_link(opts) do
    supervisor_name = Module.concat(__MODULE__, Keyword.fetch!(opts, :name))
    Supervisor.start_link(__MODULE__, opts, name: supervisor_name)
  end

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
