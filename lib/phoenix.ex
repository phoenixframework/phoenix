defmodule Phoenix do
  use Application

  @doc false
  def start(_type, _args) do
    Phoenix.Supervisor.start_link
  end
end
