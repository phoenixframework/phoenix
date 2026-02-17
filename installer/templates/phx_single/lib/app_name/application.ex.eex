defmodule <%= @app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      <%= @web_namespace %>.Telemetry,<%= if @ecto do %>
      <%= @app_module %>.Repo,<% end %><%= if @adapter_app == :ecto_sqlite3 do %>
      {Ecto.Migrator,
       repos: Application.fetch_env!(<%= inspect(String.to_atom(@app_name)) %>, :ecto_repos), skip: skip_migrations?()},<% end %>
      {DNSCluster, query: Application.get_env(<%= inspect(String.to_atom(@app_name)) %>, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: <%= @app_module %>.PubSub},
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
  end<%= if @adapter_app == :ecto_sqlite3 do %>

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end<% end %>
end
