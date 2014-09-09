defmodule Phoenix.Router.ScopeContext do
  alias Phoenix.Router.Path
  alias Phoenix.Router.Stack

  @stack_name :scopes

  @moduledoc """
  Helper functions for scopes macro.
  """

  @doc """
  Returns path, controller module alias and helper scoped to currently active scope.
  """
  def current_scope(path, controller, helper, module) do
    {
      current_path(path, module),
      current_controller(controller, module),
      current_helper(helper, module)
    }
  end

  defp current_path(relative_path, module) do
    [relative_path|get_paths(module)]
    |> Enum.reverse
    |> Path.join
  end

  defp current_controller(controller, module) do
    [controller|get_controllers(module)]
    |> Enum.reverse
    |> Module.concat
  end

  defp current_helper(nil, _module), do: nil
  defp current_helper(helper, module) do
    [helper|get_helpers(module)]
    |> Enum.reverse
    |> Enum.join("_")
  end

  defp get_paths(module) do
    get(module)
    |> Enum.map(fn {path, _, _} -> path end)
    |> Enum.filter(&(&1))
  end

  defp get_controllers(module) do
    Enum.map get(module), fn {_, controller, _} -> controller end
  end

  defp get_helpers(module) do
    get(module)
    |> Enum.map(fn {_, _, helper} -> helper end)
    |> Enum.filter(&(&1))
  end

  @doc """
  Pushes scope to scopes stack
  """
  def push(scope, module) do
    Stack.push(scope, @stack_name, module)
  end

  @doc """
  Pops scope from scopes stack
  """
  def pop(module) do
    Stack.pop(@stack_name, module)
  end

  defp get(module) do
    Stack.get(@stack_name, module)
  end
end

