defmodule Phoenix.Router.Scope do
  @moduledoc false

  @stack :plhoenix_router_scopes

  @doc """
  Builds a route based on the top of the stack.
  """
  def route(module, verb, path, controller, action, options) do
    as = Keyword.get(options, :as, Phoenix.Naming.resource_name(controller, "Controller"))
    {path, alias, as} = peek(module, path, controller, as)
    Phoenix.Router.Route.build(verb, path, alias, action, as)
  end

  @doc """
  Pushes a scope into the module stack.
  """
  def push(module, opts) do
    path  = Keyword.get(opts, :path)
    if path, do: path = Plug.Router.Utils.split(path)

    alias = Keyword.get(opts, :alias)
    if alias, do: alias = Atom.to_string(alias)

    as = Keyword.get(opts, :as)
    scope = {path, alias, as}
    Module.put_attribute(module, @stack, [scope|__stack__(module)])
  end

  @doc """
  Pops a scope from the module stack.
  """
  def pop(module) do
    [_|stack] = __stack__(module)
    Module.put_attribute(module, @stack, stack)
  end

  defp peek(module, path, alias, as) do
    stack = __stack__(module)
    {peek_path(stack, path), peek_alias(stack, alias), peek_as(stack, as)}
  end

  defp peek_path(stack, path) do
    "/" <>
      ([Plug.Router.Utils.split(path)|extract(stack, 0)]
       |> Enum.reverse()
       |> Enum.concat()
       |> Enum.join("/"))
  end

  defp peek_alias(stack, alias) when is_atom(alias) do
    [alias|extract(stack, 1)]
    |> Enum.reverse()
    |> Module.concat()
  end

  defp peek_as(_stack, nil), do: nil
  defp peek_as(stack, as) when is_atom(as) or is_binary(as) do
    [as|extract(stack, 2)]
    |> Enum.reverse()
    |> Enum.join("_")
  end

  defp extract(stack, pos) do
    for tuple <- stack,
        item = elem(tuple, pos),
        do: item
  end

  defp __stack__(module) do
    Module.get_attribute(module, @stack) || []
  end
end
