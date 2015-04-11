defmodule Phoenix do
  use Application

  @doc false
  def start(_type, _args) do
    # Warm up caches
    _ = Phoenix.Template.engines
    _ = Phoenix.Template.format_encoder("index.html")

    # Start the supervision tree
    Phoenix.Supervisor.start_link
  end
end
