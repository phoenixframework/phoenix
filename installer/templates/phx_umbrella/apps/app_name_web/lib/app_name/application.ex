defmodule <%= web_namespace %>.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      supervisor(<%= endpoint_module %>, []),
      # Start your own worker by calling: <%= web_namespace %>.Worker.start_link(arg1, arg2, arg3)
      # worker(<%= web_namespace %>.Worker, [arg1, arg2, arg3]),
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: <%= web_namespace %>.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
