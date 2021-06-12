defmodule <%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth do
  import Phoenix.LiveView, only: [assign_new: 3, push_redirect: 2]
  alias <%= inspect context.web_module %>.Router.Helpers, as: Routes

  @doc """
  Attaches current_<%= schema.singular %> to `socket` assigns based on <%= schema.singular %>_token or nil if it doesn't.

  ## Example
      # In the LiveView file
      import <%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth

      # LiveView mount
      def mount(_params, session, socket) do
        socket = mount_current_<%= schema.singular %>(socket, session)
        {:ok, socket}
      end

  """
  def mount_current_<%= schema.singular %>(socket, %{"<%=schema.singular %>_token" => <%= schema.singular %>_token}) do
    assign_new(socket, :current_<%= schema.singular %>, fn ->
      <%= inspect context.module %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    end)
  end

  def mount_current_<%= schema.singular %>(socket, _session) do
    assign_new(socket, :current_<%= schema.singular %>, fn -> nil end)
  end

  @doc """
  Attaches current_<%= schema.singular %> to `socket` assigns based on <%= schema.singular %>_token if the token exists.
  Redirect to login page if not.

  ## Example
      # In the LiveView file
      import <%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>LiveAuth

      # LiveView mount
      def mount(_params, session, socket) do
        socket = ensure_mounted_current_<%= schema.singular %>(socket, session)
        {:ok, socket}
      end

  """
  def ensure_mounted_current_<%= schema.singular %>(socket, %{"<%=schema.singular %>_token" => <%= schema.singular %>_token}) do
    assign_new(socket, :current_<%= schema.singular %>, fn ->
      <%= inspect context.module %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
    end)
  end

  def ensure_mounted_current_<%= schema.singular %>(socket, _session) do
    push_redirect(socket, to: Routes.<%= schema.route_helper %>_session_path(socket, :new))
  end
end
