defmodule Phoenix do
  use Application

  # Application callbacks

  @doc false
  def start(_type, _args) do
    Phoenix.Supervisor.start_link
  end

  @doc false
  def config_change(changed, _new, removed) do
    Phoenix.Config.config_change(changed, removed)
    :ok
  end
end
