defmodule <%= app_module %>.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
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
  end
end
