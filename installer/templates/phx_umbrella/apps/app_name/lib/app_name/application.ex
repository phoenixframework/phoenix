defmodule <%= app_module %>.Application do
  @moduledoc """
  The <%= app_module %> Application Service.

  The <%= app_name %> system business domain lives in this application.

  Exposes API to clients such as the `<%= app_module%>Web` application
  for use in channels, controllers, and elsewhere.
  """
  use Application
  <%= if Version.match?(elixir_version, "< 1.5.0") do %>
  def start(_type, _args) do<%= if ecto do %>
    import Supervisor.Spec

    Supervisor.start_link([
      supervisor(<%= app_module %>.Repo, []),
    ], strategy: :one_for_one, name: <%= app_module %>.Supervisor)<% else %>
    Supervisor.start_link([], strategy: :one_for_one, name: <%= app_module %>.Supervisor)<% end %>
  end<% else %>
  def start(_type, _args) do<%= if ecto do %>
    Supervisor.start_link([
      <%= app_module %>.Repo,
    ], strategy: :one_for_one, name: <%= app_module %>.Supervisor)<% else %>
    Supervisor.start_link([], strategy: :one_for_one, name: <%= app_module %>.Supervisor)<% end %>
  end<% end %>
end
