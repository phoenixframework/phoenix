defmodule <%= inspect live_auth_module %>Test do
  use <%= inspect context.web_module %>.ChannelCase

  alias <%= inspect context.module %>
  alias <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>LiveAuth
  alias <%= inspect context.web_module %>.Router.Helpers, as: Routes
  import <%= inspect context.module %>Fixtures

  setup do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{flash: %{}},
      endpoint: <%= inspect context.web_module %>.Endpoint
    }

    %{<%= schema.singular %>: <%= schema.singular %>_fixture(), socket: socket}
  end

  describe "mount_current_<%= schema.singular %>/2" do
    test "authenticates <%= schema.singular %> from session", %{socket: socket, <%= schema.singular %>: <%= schema.singular %>} do
      <%= schema.singular %>_token = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      session = %{"<%= schema.singular %>_token" => <%= schema.singular %>_token}
      socket = <%= inspect schema.alias %>LiveAuth.mount_current_<%= schema.singular %>(%{}, session, socket)
      assert socket.assigns.current_<%= schema.singular %>.id == <%= schema.singular %>.id
    end

    test "does not authenticate if data is missing", %{socket: socket, <%= schema.singular %>: <%= schema.singular %>} do
      _ = <%= inspect context.alias %>.generate_<%= schema.singular %>_session_token(<%= schema.singular %>)
      socket = <%= inspect schema.alias %>LiveAuth.mount_current_<%= schema.singular %>(%{}, %{}, socket)
      refute socket.assigns.current_<%= schema.singular %>
    end
  end

  describe "require_mounted_<%= schema.singular %>/2" do
    test "redirects if <%= schema.singular %> is not authenticated", %{socket: socket} do
      socket = <%= inspect schema.alias %>LiveAuth.require_mounted_<%= schema.singular %>(%{}, %{}, socket)
      assert {:live, :redirect, %{kind: :push, to: path}} = socket.redirected
      assert path == Routes.<%= schema.route_helper %>_session_path(socket, :new)
      assert socket.assigns.flash["error"] == "You must log in to access this page."
    end

    test "does not redirect if <%= schema.singular %> is authenticated", %{socket: socket, <%= schema.singular %>: <%= schema.singular %>} do
      socket = socket |> Phoenix.LiveView.assign(:current_<%= schema.singular %>, <%= schema.singular %>)
      socket = <%= inspect schema.alias %>LiveAuth.require_mounted_<%= schema.singular %>(%{}, %{}, socket)
      refute socket.redirected
    end
  end
end
