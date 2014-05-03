defmodule Phoenix.Topic.Supervisor do
  use Supervisor.Behaviour

  def start_link do
    :supervisor.start_link(__MODULE__, [])
  end

  def stop do
    if running?, do: Process.exit(supervisor_pid, :normal)
  end

  def running?, do: supervisor_pid

  defp supervisor_pid do
    case Process.whereis(__MODULE__) do
      :undefined -> nil
      pid -> pid
    end
  end

  def init(_) do
    tree = [worker(Phoenix.Topic.Server, [])]
    supervise(tree, strategy: :one_for_one)
  end
end
