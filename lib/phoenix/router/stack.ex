defmodule Phoenix.Router.Stack do

  @moduledoc """
  Stack implementation used to support nested expansion for nested resources and scopes.
  It is stored in module attribute given by the stack name.
  """

  @doc """
  Pushes the element onto the stack with given name.
  """
  def push(element, stack_name, module) do
    set([element | get(stack_name, module)], stack_name, module)
  end

  @doc """
  Pops the current element off the stack.
  """
  def pop(stack_name, module) do
    case get(stack_name, module) do
      []         -> set([], stack_name, module)
      [_ | rest] -> set(rest, stack_name, module)
    end
  end

  @doc """
  Retuns the content of the stack.
  """
  def get(stack_name, module) do
    (Module.get_attribute module, stack_name) || []
  end

  @doc """
  Sets the content of the stack.
  """
  def set(stack_content, stack_name, module) do
    Module.put_attribute module, stack_name, stack_content
  end
end

