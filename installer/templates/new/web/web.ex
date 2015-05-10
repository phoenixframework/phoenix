defmodule <%= application_module %>.Web do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use <%= application_module %>.Web, :controller
      use <%= application_module %>.Web, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """
<%= if ecto do %>
  def model do
    quote do
      use Ecto.Model
    end
  end
<% else %>
  def model do
    quote do
      # Define common model functionality
    end
  end
<% end %>
  def controller do
    quote do
      use Phoenix.Controller<%= if namespaced? do %>, namespace: <%= application_module %><% end %>
<%= if ecto do %>
      # Alias the data repository and import query/model functions
      alias <%= application_module %>.Repo
      import Ecto.Model
      import Ecto.Query, only: [from: 2]
<% end %>
      # Import URL helpers from the router
      import <%= application_module %>.Router.Helpers
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "web/templates"<%= if namespaced? do %>, namespace: <%= application_module %><% end %>

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_csrf_token: 0, get_flash: 2, view_module: 1]

      # Import URL helpers from the router
      import <%= application_module %>.Router.Helpers

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML
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
<%= if ecto do %>
      # Alias the data repository and import query/model functions
      alias <%= application_module %>.Repo
      import Ecto.Model
      import Ecto.Query, only: [from: 2]
<% end %>
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
