defmodule <%= app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      <%= if ecto do %><%= app_module %>.Repo<% else %># <%= app_module %>.Worker<% end %>
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: <%= app_module %>.Supervisor)
  end
end
