defmodule <%= web_namespace %> do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use <%= web_namespace %>, :controller
      use <%= web_namespace %>, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: <%= web_namespace %>
      import <%= web_namespace %>.Router.Helpers
      import <%= web_namespace %>.Gettext
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "lib/<%= app_name %>/web/templates",
                        namespace: <%= web_namespace %>

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]<%= if html do %>

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML<% end %>

      import <%= web_namespace %>.Router.Helpers
      import <%= web_namespace %>.ErrorHelpers
      import <%= web_namespace %>.Gettext
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import <%= web_namespace %>.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
