defmodule <%= app_module %>.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do<%= if ecto do %>
    Supervisor.start_link([
      <%= app_module %>.Repo,
    ], strategy: :one_for_one, name: <%= app_module %>.Supervisor)<% else %>
    Supervisor.start_link([], strategy: :one_for_one, name: <%= app_module %>.Supervisor)<% end %>
  end
end
