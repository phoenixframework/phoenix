defmodule Phoenix do
  @moduledoc false

  use Application

  @doc false
  def start(_type, _args) do
    Phoenix.Supervisor.start_link
  end
end
