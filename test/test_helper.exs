Code.require_file("support/router_helper.exs", __DIR__)

# Starts web server applications
Application.ensure_all_started(:cowboy)

# Used whenever a router fails. We default to simply
# rendering a short string.
defmodule Phoenix.ErrorView do
  def render(template, %{conn: conn}) do
    unless conn.private.phoenix_endpoint do
      raise "no endpoint in error view"
    end
    "#{template} from Phoenix.ErrorView"
  end
end

# For mix tests
Mix.shell(Mix.Shell.Process)

ExUnit.start()
