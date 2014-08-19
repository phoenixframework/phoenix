defmodule Phoenix.Supervisor do
  use Supervisor
  alias Phoenix.Config

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    []
    |> child(Phoenix.Topic.Supervisor, [])
    |> child(Phoenix.CodeReloader, [], Config.get([:code_reloader, :enabled]))
    |> supervise(strategy: :one_for_one)
  end

  defp child(children, mod, opts, enabled \\ true)
  defp child(children, mod, opts, true), do: [worker(mod, opts) | children]
  defp child(children, _mod, _opts, false), do: children
end
