defmodule <%= @web_namespace %> do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use <%= @web_namespace %>, :controller
      use <%= @web_namespace %>, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def controller do
    quote do
      use Phoenix.Controller, namespace: <%= @web_namespace %>

      import Plug.Conn<%= if @gettext do %>
      import <%= @web_namespace %>.Gettext<% end %>

      unquote(verified_routes())
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/<%= @lib_web_name %>/templates",
        namespace: <%= @web_namespace %>

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())
    end
  end<%= if @html do %>

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {<%= @web_namespace %>.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(view_helpers())
    end
  end<% end %>

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller<%= if @html do %>
      import Phoenix.LiveView.Router<% end %>
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: <%= @endpoint_module %>,
        router: <%= @web_namespace %>.Router,
        statics: <%= @web_namespace %>.static_paths()
    end
  end

  def channel do
    quote do
      use Phoenix.Channel<%= if @gettext do %>
      import <%= @web_namespace %>.Gettext<% end %>
    end
  end

  defp view_helpers do
    quote do<%= if @html do %>
      # Import basic HTML rendering capabilities (tags, forms, etc)
      use Phoenix.HTML

      # Import .heex helpers (<.link>, <.form>, etc) and alias JS module
      import Phoenix.LiveView.Helpers
      alias Phoenix.LiveView.JS
<% end %>
      # Include the router functionality defined above
      unquote(verified_routes())

      # All imports from the current project should be defined from here under
      import <%= @web_namespace %>.ErrorHelpers<%= if @gettext do %>
      import <%= @web_namespace %>.Gettext<% end %>
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
