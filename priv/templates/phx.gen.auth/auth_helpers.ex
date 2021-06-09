defmodule <%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>AuthHelpers do
  import Phoenix.LiveView, only: [assign_new: 3, connected?: 1]

  @doc """
  Attaches current_<%= schema.singular %> to `socket` assigns based on <%= schema.singular %>_token.

  ## Example
      # In the LiveView file
      import <%= inspect context.web_module %>.<%= if schema.web_path, do: "#{Phoenix.Naming.humanize(schema.web_path)}.", else: "" %><%= Phoenix.Naming.humanize(schema.singular) %>AuthHelpers

      # LiveView mount
      def mount(_params, session, socket) do
        socket = mount_current_<%= schema.singular %>(socket, session)
        {:ok, socket}
      end

  """
  def mount_current_<%= schema.singular %>(socket, %{"<%=schema.singular %>_token" => <%= schema.singular %>_token}) do
    if connected?(socket) do
      assign_new(socket, :current_<%= schema.singular %>, fn ->
        <%= inspect context.module %>.get_<%= schema.singular %>_by_session_token(<%= schema.singular %>_token)
      end)
    else
      assign_new(socket, :current_<%= schema.singular %>, fn -> nil end)
    end
  end

  def mount_current_<%= schema.singular %>(socket, _session) do
    assign_new(socket, :current_<%= schema.singular %>, fn -> nil end)
  end
end
