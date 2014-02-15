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
    case get_paths(module) do
      []    -> relative_path
      paths -> paths
               |> Enum.reverse
               |> Kernel.++([relative_path])
               |> Path.join
    end
  end

  defp current_controller(controller, module) do
    case get_controllers(module) do
      []          -> controller
      controllers -> controllers
                     |> Enum.reverse
                     |> Kernel.++([controller])
                     |> Module.concat
    end
  end

  defp current_helper(nil, _module), do: nil
  defp current_helper(helper, module) do
    case get_helpers(module) do
      []      -> helper
      helpers -> helpers
                 |> Enum.reverse
                 |> Kernel.++([helper])
                 |> Enum.join("_")
    end
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
    Enum.map get(module), fn {_, _, helper} -> helper end
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

