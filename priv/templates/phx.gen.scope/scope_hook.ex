defmodule <%= inspect(scope.hook_module) %> do
  @moduledoc """
  Provides Phoenix.LiveView lifecycle hooks for assigning the scope.
  """
  import Phoenix.Component

  alias <%= inspect(scope.module) %>

  def assign_scope(%Plug.Conn{} = conn, _opts) do
    peer_data = Plug.Conn.get_peer_data(conn)
    current_user = conn.assigns[:current_user]
    scope = Scope.for_user(current_user, session, peer_data)
    Plug.Conn.assign(conn, scope: scope)
  end

  def on_mount(:default, _params, session, socket) do
    peer_data = get_connect_info(socket, :peer_data)
    current_user = socket.assigns[:current_user]
    scope = Scope.for_user(current_user, session, peer_data)
    {:cont, assign(socket, scope: scope)}
  end
end
