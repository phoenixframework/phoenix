defmodule <%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth do
  import Phoenix.LiveView, only: [assign_new: 3, push_redirect: 2]
  alias <%= inspect context.web_module %>.Router.Helpers, as: Routes

  @doc """
  mount_current_<%= schema.singular %>:
  Attaches current_<%= schema.singular %> to `socket` assigns based on <%= schema.singular %>_token or nil if it doesn't.

  ensure_mounted_current_<%= schema.singular %>:
  Attaches current_<%= schema.singular %> to `socket` assigns based on <%= schema.singular %>_token if the token exists.
  Redirect to login page if not.

  ## Examples

      # In the LiveView file
      defmodule DemoWeb.PageLive do
        use Phoenix.LiveView

        on_mount {<%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth, :mount_current_<%= schema.singular %>}
        # or
        on_mount {<%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth, :ensure_mounted_current_<%= schema.singular %>}
      end

  """
  def on_mount(:mount_current_<%= schema.singular %>, _params, %{"<%=schema.singular %>_token" => <%= schema.singular %>_token}, socket) do
    socket =
      assign_new(socket, :current_<%= schema.singular %>, fn ->
        <%= inspect context.module %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
      end)

    {:cont, socket}
  end

  def on_mount(:mount_current_<%= schema.singular %>, _params, _session, socket) do
    {:cont, assign_new(socket, :current_<%= schema.singular %>, fn -> nil end)}
  end

  def on_mount(:ensure_mounted_current_<%= schema.singular %>, _params, %{"<%=schema.singular %>_token" => <%= schema.singular %>_token}, socket) do
    socket =
      assign_new(socket, :current_<%= schema.singular %>, fn ->
        <%= inspect context.module %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
      end)

    case socket.assigns.current_<%= schema.singular %> do
      nil ->
        {:halt, push_redirect(socket, to: Routes.<%= schema.route_helper %>_session_path(socket, :new))}

      _ ->
        {:cont, socket}
    end
  end

  def on_mount(:ensure_mounted_current_<%= schema.singular %>, _params, _session, socket) do
    {:halt, push_redirect(socket, to: Routes.<%= schema.route_helper %>_session_path(socket, :new))}
  end
end
