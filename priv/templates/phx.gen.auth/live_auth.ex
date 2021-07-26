defmodule <%= inspect live_auth_module %> do
  import Phoenix.LiveView, only: [assign_new: 3, push_redirect: 2, put_flash: 3]
  alias <%= inspect context.web_module %>.Router.Helpers, as: Routes

  @doc """
  Mounts current_<%= schema.singular %> to `socket` assigns based on <%= schema.singular %>_token or nil if it doesn't.

  ## Example

      defmodule DemoWeb.PageLive do
        use Phoenix.LiveView, :live_view

        import DemoWeb.<%= inspect live_auth_module %>

        on_mount {DemoWeb.LiveAuth, :mount_current_<%= schema.singular %>}
      end
  """
  def mount_current_<%= schema.singular %>(_params, %{"<%=schema.singular %>_token" => <%= schema.singular %>_token}, socket) do
    assign_new(socket, :current_<%= schema.singular %>, fn ->
      <%= inspect context.module %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    end)
  end

  def mount_current_<%= schema.singular %>(_params, _session, socket) do
    assign_new(socket, :current_<%= schema.singular %>, fn -> nil end)
  end

  @doc """
  This function should be used in conjunction with mount_current_<%= schema.singular %>
  Requires that current_<%= schema.singular %> is mounted to `socket`.
  Otherwise it will flash an error message and redirect the user to log in.

  ## Example

      defmodule DemoWeb.PageLive do
        use Phoenix.LiveView, :live_view

        import DemoWeb.<%= inspect live_auth_module %>

        on_mount {DemoWeb.LiveAuth, :mount_current_<%= schema.singular %>}
        on_mount {DemoWeb.LiveAuth, :require_mounted_<%= schema.singular %>}
      end
  """
  def require_mounted_<%= schema.singular %>(_params, _session, socket) do
    if socket.assigns[:current_<%= schema.singular %>] do
      socket
    else
      socket
      |> put_flash(:error, "You must log in to access this page.")
      |> push_redirect(to: Routes.<%= schema.route_helper %>_session_path(socket, :new))
    end
  end
end
