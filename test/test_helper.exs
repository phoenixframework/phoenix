Code.require_file("router_helper.exs", __DIR__)

# Starts web server applications
Application.ensure_all_started(:cowboy)

# Used whenever a router fails. We default to simply
# rendering a short string.
defmodule Phoenix.ErrorView do
  def render(template, _assigns) do
    "#{template} from Phoenix.ErrorView"
  end
end

# Start transport levels
Process.flag(:trap_exit, true)

Process.flag(:trap_exit, false)
ExUnit.start()
