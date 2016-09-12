defmodule <%= application_module %> do
  @moduledoc """
  The <%= application_module %> Application Service.

  The <%= application_name %> system business domain lives in this application.

  Exposes API to clients such as the `<%= application_module%>.Web` application
  for use in channels, controllers, and elsewhere.
  """
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    Supervisor.start_link([
      <%= if ecto do %>worker(<%= application_module %>.Repo, []),<% end %>
    ], strategy: :one_for_one, name: <%= application_module %>.Supervisor)
  end
end
