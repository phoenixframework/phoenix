defmodule Phoenix do
  use Application

  @doc false
  def start(_type, _args) do
    # Work around the fact consolidation for some
    # protocols is not working currently
    :code.delete(Access)
    :code.delete(Collectable)

    # Warm up caches
    _ = Phoenix.Template.engines
    _ = Phoenix.Template.format_encoder("index.html")

    # Start the supervision tree
    Phoenix.Supervisor.start_link
  end
end
