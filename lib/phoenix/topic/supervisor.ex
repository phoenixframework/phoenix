defmodule Phoenix.Topic.Supervisor do
  use Supervisor.Behaviour

  def start_link do
    :supervisor.start_link({:local, __MODULE__}, __MODULE__, [])
  end

  def pid do
    case Process.whereis(__MODULE__) do
      :undefined -> nil
      pid -> pid
    end
  end

  def init(_) do
    tree = [worker(Phoenix.Topic.Server, [])]
    supervise tree, strategy: :one_for_one,
                    max_restarts: 5,
                    max_seconds: 5
  end
end
