defmodule <%= @app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      <%= @web_namespace %>.Telemetry,<%= if @ecto do %>
      <%= @app_module %>.Repo,<% end %>
      {Phoenix.PubSub, name: <%= @app_module %>.PubSub},<%= if @mailer do %>
      # Start the Finch HTTP client for sending emails
      {Finch, name: <%= @app_module %>.Finch},<% end %>
      # Start a worker by calling: <%= @app_module %>.Worker.start_link(arg)
      # {<%= @app_module %>.Worker, arg},
      # Start to serve requests, typically the last entry
      <%= @endpoint_module %>
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: <%= @app_module %>.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    <%= @endpoint_module %>.config_change(changed, removed)
    :ok
  end
end
