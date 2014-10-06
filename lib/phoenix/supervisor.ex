defmodule Phoenix.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    []
    |> child(Phoenix.Topic.Supervisor, [], true)
    |> child(Phoenix.CodeReloader, [], Application.get_env(:phoenix, :code_reloader))
    |> supervise(strategy: :one_for_one)
  end

  defp child(children, mod, opts, true), do: [worker(mod, opts) | children]
  defp child(children, _mod, _opts, false), do: children
end
