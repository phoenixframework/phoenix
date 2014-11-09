defmodule Phoenix.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    topics = Application.get_env(:phoenix, :topics)

    []
    |> child(Phoenix.Config.Supervisor, [], true)
    |> child(Phoenix.Topic.Server, [topics], true)
    |> child(Phoenix.Transports.LongPoller.Supervisor, [], true)
    |> child(Phoenix.CodeReloader, [], Application.get_env(:phoenix, :code_reloader))
    |> supervise(strategy: :one_for_one)
  end

  defp child(children, mod, args, true), do: [worker(mod, args) | children]
  defp child(children, _mod, _args, false), do: children
end
