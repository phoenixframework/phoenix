defmodule Phoenix.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    children = [
      supervisor(Phoenix.Transports.LongPoll.Supervisor, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
