defmodule <%= application_module %>.Web do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use <%= application_module %>.Web, :controller
      use <%= application_module %>.Web, :view

  Keep the definitions in this module short and clean,
  mostly focused on imports, uses and aliases.
  """

  def view do
    quote do
      use Phoenix.View, root: "web/templates"

      # Import URL helpers from the router
      import <%= application_module %>.Router.Helpers

      # Import all HTML functions (forms, tags, etc)
      use Phoenix.HTML
    end
  end

  def controller do
    quote do
      use Phoenix.Controller
<%= if ecto do %>
      # Alias the data repository as a convenience
      alias <%= application_module %>.Repo
<% end %>
      # Import URL helpers from the router
      import <%= application_module %>.Router.Helpers
    end
  end
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
  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
