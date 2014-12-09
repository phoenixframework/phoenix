defmodule <%= application_module %> do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(<%= application_module %>.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: <%= application_module %>.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the cached endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Phoenix.Config.config_change(<%= application_module %>.Endpoint, changed, removed)
    :ok
  end
end
