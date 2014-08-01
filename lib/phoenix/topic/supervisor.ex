defmodule Phoenix.Topic.Supervisor do
  use Supervisor
  alias Phoenix.Config

  def start_link do
    Supervisor.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def pid do
    case Process.whereis(__MODULE__) do
      :undefined -> nil
      pid -> pid
    end
  end

  def init(_) do
    gc_after = Config.get!([:topics, :garbage_collect_after_ms])

    tree = [worker(Phoenix.Topic.Server, [[garbage_collect_after_ms: gc_after]])]
    supervise tree, strategy: :one_for_one,
                    max_restarts: 5,
                    max_seconds: 5
  end
end
