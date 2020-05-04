defmodule Phoenix.Router.Scope do
  alias Phoenix.Router.{Scope, Route}
  @moduledoc false

  @stack :phoenix_router_scopes
  @pipes :phoenix_pipeline_scopes
  @top :phoenix_top_scopes

  defstruct path: [], alias: [], as: [], pipes: [], host: nil, private: %{}, assigns: %{}, log: :debug, trailing_slash?: false

  @doc """
  Initializes the scope.
  """
  def init(module) do
    Module.put_attribute(module, @stack, [])
    Module.put_attribute(module, @top, %Scope{})
    Module.put_attribute(module, @pipes, MapSet.new())
  end

  @doc """
  Builds a route based on the top of the stack.
  """
  def route(line, module, kind, verb, path, plug, plug_opts, opts) do
    top = get_top(module)
    path    = validate_path(path)
    private = Keyword.get(opts, :private, %{})
    assigns = Keyword.get(opts, :assigns, %{})
    as      = Keyword.get(opts, :as, Phoenix.Naming.resource_name(plug, "Controller"))
    alias?  = Keyword.get(opts, :alias, true)
    trailing_slash? = Keyword.get(opts, :trailing_slash, top.trailing_slash?) == true

    if to_string(as) == "static"  do
      raise ArgumentError, "`static` is a reserved route prefix generated from #{inspect plug} or `:as` option"
    end

    {path, alias, as, private, assigns} =
      join(top, path, plug, alias?, as, private, assigns)

    metadata =
      opts
      |> Keyword.get(:metadata, %{})
      |> Map.put(:log, Keyword.get(opts, :log, top.log))

    Phoenix.Router.Route.build(line, kind, verb, path, top.host, alias, plug_opts, as, top.pipes, private, assigns, metadata, trailing_slash?)
  end

  @doc """
  Validates a path is a string and contains a leading prefix.
  """
  def validate_path("/" <> _ = path), do: path
  def validate_path(path) when is_binary(path) do
    IO.warn """
    router paths should begin with a forward slash, got: #{inspect path}
    #{Exception.format_stacktrace()}
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
    %{pipes: pipes} = top = get_top(module)

    if pipe = Enum.find(new_pipes, & &1 in pipes) do
      raise ArgumentError,
            "duplicate pipe_through for #{inspect pipe}. " <>
              "A plug may only be used once inside a scoped pipe_through"
    end

    put_top(module, %{top | pipes: pipes ++ new_pipes})
  end

  @doc """
  Pushes a scope into the module stack.
  """
  def push(module, path) when is_binary(path) do
    push(module, path: path)
  end

  def push(module, opts) when is_list(opts) do
    top = get_top(module)

    path =
      if path = Keyword.get(opts, :path) do
        path |> validate_path() |> String.split("/", trim: true)
      else
        []
      end

    alias = append_unless_false(top, opts, :alias, &Atom.to_string(&1))
    as = append_unless_false(top, opts, :as, & &1)
    host = Keyword.get(opts, :host)
    private = Keyword.get(opts, :private, %{})
    assigns = Keyword.get(opts, :assigns, %{})

    update_stack(module, fn stack -> [top | stack] end)

    put_top(module, %Scope{
      path: top.path ++ path,
      alias: alias,
      as: as,
      host: host || top.host,
      pipes: top.pipes,
      private: Map.merge(top.private, private),
      assigns: Map.merge(top.assigns, assigns),
      log: Keyword.get(opts, :log, top.log),
      trailing_slash?: Keyword.get(opts, :trailing_slash, top.trailing_slash?) == true
    })
  end

  defp append_unless_false(top, opts, key, fun) do
    case opts[key] do
      false -> []
      nil -> Map.fetch!(top, key)
      other -> Map.fetch!(top, key) ++ [fun.(other)]
    end
  end

  @doc """
  Pops a scope from the module stack.
  """
  def pop(module) do
    update_stack(module, fn [top | stack] ->
      put_top(module, top)
      stack
    end)
  end

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

  @doc """
  Expands the alias in the current router scope.
  """
  def expand_alias(module, alias) do
    join_alias(get_top(module), alias)
  end

  defp join(top, path, alias, alias?, as, private, assigns) do
    joined_alias =
      if alias? do
        join_alias(top, alias)
      else
        alias
      end

    {join_path(top, path), joined_alias, join_as(top, as),
     Map.merge(top.private, private), Map.merge(top.assigns, assigns)}
  end

  defp join_path(top, path) do
    "/" <> Enum.join(top.path ++ String.split(path, "/", trim: true), "/")
  end

  defp join_alias(top, alias) when is_atom(alias) do
    Module.concat(top.alias ++ [alias])
  end

  defp join_as(_top, nil), do: nil
  defp join_as(top, as) when is_atom(as) or is_binary(as), do: Enum.join(top.as ++ [as], "_")

  defp get_top(module) do
    get_attribute(module, @top)
  end

  defp update_stack(module, fun) do
    update_attribute(module, @stack, fun)
  end

  defp update_pipes(module, fun) do
    update_attribute(module, @pipes, fun)
  end

  defp put_top(module, value) do
    Module.put_attribute(module, @top, value)
    value
  end

  defp get_attribute(module, attr) do
    Module.get_attribute(module, attr) ||
      raise "Phoenix router scope was not initialized"
  end

  defp update_attribute(module, attr, fun) do
    Module.put_attribute(module, attr, fun.(get_attribute(module, attr)))
  end
end
