Code.require_file("support/router_helper.exs", __DIR__)

# Starts web server applications
Application.ensure_all_started(:cowboy)

# TODO v1.4: Remove this since Elixir v1.3 will no longer be supported
if Version.match?(System.version, "~> 1.3.0") do
  ExUnit.configure exclude: [:phoenix_new, :phx_new]
end

# Used whenever a router fails. We default to simply
# rendering a short string.
defmodule Phoenix.ErrorView do
  def render("404.json", %{kind: kind, reason: _reason, stack: _stack, conn: conn}) do
    %{error: "Got 404 from #{kind} with #{conn.method}"}
  end

  def render(template, %{conn: conn}) do
    unless conn.private.phoenix_endpoint do
      raise "no endpoint in error view"
    end
    "#{template} from Phoenix.ErrorView"
  end
end

# For mix tests
Mix.shell(Mix.Shell.Process)

ExUnit.start(assert_receive_timeout: 200)
