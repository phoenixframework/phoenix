defmodule <%= app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  <%= if Version.match?(elixir_version, "< 1.5.0") do %>
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [<%= if ecto do %>
      # Start the Ecto repository
      supervisor(<%= app_module %>.Repo, []),<% end %>
      # Start the endpoint when the application starts
      supervisor(<%= endpoint_module %>, []),
      # Start your own worker by calling: <%= app_module %>.Worker.start_link(arg1, arg2, arg3)
      # worker(<%= app_module %>.Worker, [arg1, arg2, arg3]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: <%= app_module %>.Supervisor]
    Supervisor.start_link(children, opts)
  end<% else %>
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [<%= if ecto do %>
      # Start the Ecto repository
      <%= app_module %>.Repo,<% end %>
      # Start the endpoint when the application starts
      <%= endpoint_module %>,
      # Starts a worker by calling: <%= app_module %>.Worker.start_link(arg)
      # {<%= app_module %>.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: <%= app_module %>.Supervisor]
    Supervisor.start_link(children, opts)
  end<% end %>

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    <%= endpoint_module %>.config_change(changed, removed)
    :ok
  end
end
