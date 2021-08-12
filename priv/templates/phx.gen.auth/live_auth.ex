defmodule <%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth do
  import Phoenix.LiveView, only: [assign_new: 3, push_redirect: 2]
  alias <%= inspect context.web_module %>.Router.Helpers, as: Routes

  @doc """
  Attaches current_<%= schema.singular %> to `socket` assigns based on <%= schema.singular %>_token or nil if it doesn't.

  ## Examples

      # In the LiveView file
      defmodule DemoWeb.PageLive do
        use Phoenix.LiveView

        on_mount {<%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth, :mount_current_<%= schema.singular %>}
      end

  """
  def mount_current_<%= schema.singular %>(socket, %{"<%=schema.singular %>_token" => <%= schema.singular %>_token}) do
    socket = assign_new(socket, :current_<%= schema.singular %>, fn ->
      <%= inspect context.module %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    end)

    {:cont, socket}
  end

  def mount_current_<%= schema.singular %>(socket, _session) do
    {:cont, assign_new(socket, :current_<%= schema.singular %>, fn -> nil end)}
  end

  @doc """
  Attaches current_<%= schema.singular %> to `socket` assigns based on <%= schema.singular %>_token if the token exists.
  Redirect to login page if not.

  ## Examples

      # In the LiveView file
      defmodule DemoWeb.PageLive do
        use Phoenix.LiveView

        on_mount {<%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth, :ensure_mounted_current_<%= schema.singular %>}
      end

  """
  def ensure_mounted_current_<%= schema.singular %>(socket, %{"<%=schema.singular %>_token" => <%= schema.singular %>_token}) do
    socket = assign_new(socket, :current_<%= schema.singular %>, fn ->
      <%= inspect context.module %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    end)

    case socket.assigns.current_<%= schema.singular %> do
      nil ->
        {:halt, push_redirect(socket, to: Routes.<%= schema.route_helper %>_session_path(socket, :new))}

      _ ->
        {:cont, socket}
    end
  end

  def ensure_mounted_current_<%= schema.singular %>(socket, _session) do
    {:halt, push_redirect(socket, to: Routes.<%= schema.route_helper %>_session_path(socket, :new))}
  end
end
