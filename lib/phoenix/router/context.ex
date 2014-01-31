defmodule Phoenix.Router.Context do
  import Inflex

  @moduledoc """
  Helper functions for pushing and popping nested Route contexts
  and maintaining prefix state during nested expansion
  """

  @doc """
  Returns the String route prefix based on current context
  of module and relative path.

  # Examples

    resources "users", Users do
      resources "comments", Comments
      -------------------------------
      Context.current_prefix("comments")
      => "users/:user_id/comments"
      -------------------------------
    end
    resources "pages", Pages
    ---------------------------------
    Context.current_prefix("pages")
    => "pages"
    ---------------------------------

  """
  def current_prefix(relative_path, module) do
    case get(module) do
      [] -> relative_path
      contexts -> (contexts |> Enum.reverse |> Path.join) <> "/#{relative_path}"
    end
  end


  @doc """
  Pushes the current prefix onto contexts stack for given module
  and sets new state in module :nested_context attribute
  """
  def push(prefix, module) do
    set([prefix_with_resource_param(prefix) | get(module)], module)
  end


  @doc """
  Pops the current prefix off contexts stack for given module
  and sets new state in module :nested_context attribute
  """
  def pop(module) do
    case get(module) do
      []       -> set([], module)
      [_|rest] -> set(rest, module)
    end
  end


  @doc """
  Returns the current stack of contexts stored in nested_context
  attribute of module
  """
  def get(module) do
    (Module.get_attribute module, :nested_context) || []
  end


  @doc """
  Updates the current contexts state of nested_context
  attribute of module
  """
  def set(context, module) do
    Module.put_attribute module, :nested_context, context
  end


  @doc """
  Appends the singularized inflection of named resource parameter based
  on current route prefix

  # Examples
  iex> Context.prefix_with_resource_param("users")
  "users/:user_id"

  """
  def prefix_with_resource_param(prefix) do
    Path.join([prefix, ":#{singularize(prefix)}_id"])
  end
end
