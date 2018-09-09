defmodule Phoenix.Router.Scope do
  alias Phoenix.Router.{Scope, Route}
  @moduledoc false

  @stack :phoenix_router_scopes
  @pipes :phoenix_pipeline_scopes

  defstruct path: nil, alias: nil, as: nil, pipes: [], host: nil, private: %{}, assigns: %{}

  @doc """
  Initializes the scope.
  """
  def init(module) do
    Module.put_attribute(module, @stack, [%Scope{}])
    Module.put_attribute(module, @pipes, MapSet.new)
  end

  @doc """
  Builds a route based on the top of the stack.
  """
  def route(line, module, kind, verb, path, plug, plug_opts, opts) do
    path    = validate_path(path)
    private = Keyword.get(opts, :private, %{})
    assigns = Keyword.get(opts, :assigns, %{})
    as      = Keyword.get(opts, :as, Phoenix.Naming.resource_name(plug, "Controller"))

    {path, host, alias, as, pipes, private, assigns} =
      join(module, path, plug, as, private, assigns)
    Phoenix.Router.Route.build(line, kind, verb, path, host, alias, plug_opts, as, pipes, private, assigns)
  end

  @doc """
  Validates a path is a string and contains a leading prefix.
  """
  def validate_path("/" <> _ = path), do: path
  def validate_path(path) when is_binary(path) do
    IO.warn """
    router paths should begin with a forward slash, got: #{inspect path}
    #{Exception.format_stacktrace}
    """

    "/" <> path
  end
  def validate_path(path) do
    raise ArgumentError, "router paths must be strings, got: #{inspect path}"
  end

  @doc """
  Defines the given pipeline.
  """
  def pipeline(module, pipe) when is_atom(pipe) do
    update_pipes module, &MapSet.put(&1, pipe)
  end

  @doc """
  Appends the given pipes to the current scope pipe through.
  """
  def pipe_through(module, new_pipes) do
    new_pipes = List.wrap(new_pipes)
    stack_pipes =
      module
      |> get_stack()
      |> Enum.flat_map(fn scope -> scope.pipes end)

    update_stack(module, fn [scope | stack] ->
      pipes = collect_pipes(new_pipes, stack_pipes, scope.pipes)
      [put_in(scope.pipes, pipes) | stack]
    end)
  end
  defp collect_pipes([] = _new_pipes, _stack_pipes, acc), do: acc
  defp collect_pipes([pipe | new_pipes], stack_pipes, acc) do
    if pipe in new_pipes or pipe in stack_pipes do
      raise ArgumentError, """
      duplicate pipe_through for #{inspect pipe}.
      A plug may only be used once inside a scoped pipe_through
      """
    end
    collect_pipes(new_pipes, stack_pipes, acc ++ [pipe])
  end

  @doc """
  Pushes a scope into the module stack.
  """
  def push(module, path) when is_binary(path) do
    push(module, path: path)
  end

  def push(module, opts) when is_list(opts) do
    path = with path when not is_nil(path) <- Keyword.get(opts, :path),
                path <- validate_path(path),
                do: String.split(path, "/", trim: true)

    alias = Keyword.get(opts, :alias)
    alias = alias && Atom.to_string(alias)

    scope = %Scope{path: path,
                   alias: alias,
                   as: Keyword.get(opts, :as),
                   host: Keyword.get(opts, :host),
                   pipes: [],
                   private: Keyword.get(opts, :private, %{}),
                   assigns: Keyword.get(opts, :assigns, %{})}

    update_stack(module, fn stack -> [scope|stack] end)
  end

  @doc """
  Pops a scope from the module stack.
  """
  def pop(module) do
    update_stack(module, fn [_|stack] -> stack end)
  end

  @doc """
  Returns true if the module's definition is currently within a scope block.
  """
  def inside_scope?(module), do: length(get_stack(module)) > 1

  @doc """
  Add a forward to the router.
  """
  def register_forwards(module, path, plug) when is_atom(plug) do
    plug = expand_alias(module, plug)
    phoenix_forwards = Module.get_attribute(module, :phoenix_forwards)
    path_segments = Route.forward_path_segments(path, plug, phoenix_forwards)
    phoenix_forwards = Map.put(phoenix_forwards, plug, path_segments)
    Module.put_attribute(module, :phoenix_forwards, phoenix_forwards)
    plug
  end

  def register_forwards(_, _, plug) do
    raise ArgumentError, "forward expects a module as the second argument, #{inspect plug} given"
  end

  defp expand_alias(module, alias) do
    if inside_scope?(module) do
      module
      |> get_stack()
      |> join_alias(alias)
    else
      alias
    end
  end

  defp join(module, path, alias, as, private, assigns) do
    stack = get_stack(module)
    {join_path(stack, path), find_host(stack), join_alias(stack, alias),
     join_as(stack, as), join_pipe_through(stack), join_private(stack, private),
     join_assigns(stack, assigns)}
  end

  defp join_path(stack, path) do
    "/" <>
      ([String.split(path, "/", trim: true) | extract(stack, :path)]
       |> Enum.reverse()
       |> Enum.concat()
       |> Enum.join("/"))
  end

  defp join_alias(stack, alias) when is_atom(alias) do
    [alias|extract(stack, :alias)]
    |> Enum.reverse()
    |> Module.concat()
  end

  defp join_as(_stack, nil), do: nil
  defp join_as(stack, as) when is_atom(as) or is_binary(as) do
    [as|extract(stack, :as)]
    |> Enum.reverse()
    |> Enum.join("_")
  end

  defp join_private(stack, private) do
    Enum.reduce stack, private, &Map.merge(&1.private, &2)
  end

  defp join_assigns(stack, assigns) do
    Enum.reduce stack, assigns, &Map.merge(&1.assigns, &2)
  end

  defp join_pipe_through(stack) do
    for scope <- Enum.reverse(stack),
        item <- scope.pipes,
        do: item
  end

  defp find_host(stack) do
    Enum.find_value(stack, & &1.host)
  end

  defp extract(stack, attr) do
    for scope <- stack,
        item = Map.fetch!(scope, attr),
        do: item
  end

  defp get_stack(module) do
    get_attribute(module, @stack)
  end

  defp update_stack(module, fun) do
    update_attribute(module, @stack, fun)
  end

  defp update_pipes(module, fun) do
    update_attribute(module, @pipes, fun)
  end

  defp get_attribute(module, attr) do
    Module.get_attribute(module, attr) ||
      raise "Phoenix router scope was not initialized"
  end

  defp update_attribute(module, attr, fun) do
    Module.put_attribute(module, attr, fun.(get_attribute(module, attr)))
  end
end
