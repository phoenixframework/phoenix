defmodule Phoenix.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    pubsub = Application.get_env(:phoenix, :pubsub)
    code_reloader = Application.get_env(:phoenix, :code_reloader)

    []
    |> child(Phoenix.PubSub.Server, [pubsub], true)
    |> child(Phoenix.CodeReloader.Server, [], code_reloader)
    |> child(Phoenix.Transports.LongPoller.Supervisor, [], true)
    |> supervise(strategy: :one_for_one)
  end

  defp child(children, mod, args, true), do: [worker(mod, args) | children]
  defp child(children, _mod, _args, false), do: children
end
