defmodule <%= app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [<%= if ecto do %>
      # Start the Ecto repository
      <%= app_module %>.Repo,<% end %>
      # Start the Telemetry supervisor
      <%= web_namespace %>.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: <%= app_module %>.PubSub},
      # Start the Endpoint (http/https)
      <%= endpoint_module %>
      # Start a worker by calling: <%= app_module %>.Worker.start_link(arg)
      # {<%= app_module %>.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: <%= app_module %>.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    <%= endpoint_module %>.config_change(changed, removed)
    :ok
  end
end
