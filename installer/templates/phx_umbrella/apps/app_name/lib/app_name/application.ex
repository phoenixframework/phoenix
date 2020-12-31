defmodule <%= @app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [<%= if @ecto do %>
      # Start the Ecto repository
      <%= @app_module %>.Repo,<% end %>
      # Start the PubSub system
      {Phoenix.PubSub, name: <%= @app_module %>.PubSub}
      # Start a worker by calling: <%= @app_module %>.Worker.start_link(arg)
      # {<%= @app_module %>.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: <%= @app_module %>.Supervisor)
  end
end
