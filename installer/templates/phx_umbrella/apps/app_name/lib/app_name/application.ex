defmodule <%= @app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [<%= if @ecto do %>
      <%= @app_module %>.Repo,<% end %><%= if @adapter_app == :ecto_sqlite3 do %>
      {Ecto.Migrator,
        repos: Application.fetch_env!(<%= inspect String.to_atom(@app_name) %>, :ecto_repos),
        skip: skip_migrations?()},<% end %>
      {Phoenix.PubSub, name: <%= @app_module %>.PubSub}<%= if @mailer do %>,
      # Start the Finch HTTP client for sending emails
      {Finch, name: <%= @app_module %>.Finch}<% end %>
      # Start a worker by calling: <%= @app_module %>.Worker.start_link(arg)
      # {<%= @app_module %>.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: <%= @app_module %>.Supervisor)
  end<%= if @adapter_app == :ecto_sqlite3 do %>

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") != nil
  end<% end %>
end
