defmodule Phoenix.Router.Route do
  # This module defines the Route struct that is used
  # throughout Phoenix's router. This struct is private
  # as it contains internal routing information.
  @moduledoc false

  alias Phoenix.Router.Route

  @doc """
  The `Phoenix.Router.Route` struct. It stores:

    * :verb - the HTTP verb as an upcased string
    * :kind - the kind of route, one of `:match`, `:forward`
    * :path - the normalized path as string
    * :host - the request host or host prefix
    * :plug - the plug module
    * :opts - the plug options
    * :helper - the name of the helper as a string (may be nil)
    * :private - the private route info
    * :assigns - the route info
    * :pipe_through - the pipeline names as a list of atoms

  """

  defstruct [:verb, :kind, :path, :host, :plug, :opts,
             :helper, :private, :pipe_through, :assigns]

  @type t :: %Route{}

  @doc """
  Receives the verb, path, plug, options and helper
  and returns a `Phoenix.Router.Route` struct.
  """
  @spec build(:match | :forward, String.t, String.t, String.t | nil, atom, atom, atom | nil, atom, %{}, %{}) :: t
  def build(kind, verb, path, host, plug, opts, helper, pipe_through, private, assigns)
      when is_atom(verb) and (is_binary(host) or is_nil(host)) and
           is_atom(plug) and (is_binary(helper) or is_nil(helper)) and
           is_list(pipe_through) and is_map(private) and is_map(assigns)
           and kind in [:match, :forward] do

    %Route{kind: kind, verb: verb, path: path, host: host, private: private,
           plug: plug, opts: opts, helper: helper,
           pipe_through: pipe_through, assigns: assigns}
  end

  @doc """
  Builds the expressions used by the route.
  """
  def exprs(route) do
    {path, binding} = build_path_and_binding(route)

    %{path: path,
      host: build_host(route.host),
      verb_match: verb_match(route.verb),
      binding: binding,
      dispatch: build_dispatch(route, binding)}
  end

  defp verb_match(:*), do: Macro.var(:_verb, nil)
  defp verb_match(verb), do: verb |> to_string() |> String.upcase()

  defp build_path_and_binding(%Route{path: path} = route) do
    {params, segments} = case route.kind do
      :forward -> Plug.Router.Utils.build_path_match(path <> "/*_forward_path_info")
      :match   -> Plug.Router.Utils.build_path_match(path)
    end

    binding = for var <- params, var != :_forward_path_info do
      {Atom.to_string(var), Macro.var(var, nil)}
    end

    {segments, binding}
  end

  defp build_host(host) do
    cond do
      is_nil(host)             -> quote do: _
      String.last(host) == "." -> quote do: unquote(host) <> _
      true                     -> host
    end
  end

  defp build_dispatch(route, binding) do
    exprs =
      [maybe_binding(binding),
       maybe_merge(:private, route.private),
       maybe_merge(:assigns, route.assigns),
       build_pipes(route)]

    {:__block__, [], Enum.filter(exprs, & &1 != nil)}
  end

  defp maybe_merge(key, data) do
    if map_size(data) > 0 do
      quote do
        var!(conn) =
          update_in var!(conn).unquote(key), &Map.merge(&1, unquote(Macro.escape(data)))
      end
    end
  end

  defp maybe_binding([]), do: nil
  defp maybe_binding(binding) do
    quote do
      var!(conn) =
        update_in var!(conn).params, &Map.merge(&1, unquote({:%{}, [], binding}))
    end
  end

  defp build_pipes(%Route{kind: :forward} = route) do
    {_params, fwd_segments} = Plug.Router.Utils.build_path_match(route.path)
    opts = route.opts |> route.plug.init() |> Macro.escape()

    quote do
      var!(conn)
      |> Plug.Conn.put_private(:phoenix_pipelines, unquote(route.pipe_through))
      |> Plug.Conn.put_private(:phoenix_route, fn conn ->
        Phoenix.Router.Route.forward(conn, unquote(fwd_segments),
                                     unquote(route.plug), unquote(opts))
      end)
    end |> pipe_through(route)
  end

  defp build_pipes(route) do
    quote do
      var!(conn)
      |> Plug.Conn.put_private(:phoenix_pipelines, unquote(route.pipe_through))
      |> Plug.Conn.put_private(:phoenix_route, fn conn ->
        # We need to store this in a variable so the compiler
        # does not see a call and then suddenly start tracking
        # changes in the controller.
        plug = unquote(route.plug)
        opts = plug.init(unquote(route.opts))
        plug.call(conn, opts)
      end)
    end |> pipe_through(route)
  end

  defp pipe_through(initial, route) do
    plugs = route.pipe_through |> Enum.reverse |> Enum.map(&{&1, [], true})
    {conn, body} = Plug.Builder.compile(__ENV__, plugs, [])
    quote do
      unquote(conn) = unquote(initial)
      unquote(body)
    end
  end

  @doc """
  Forwards requests to another Plug at a new path.
  """
  def forward(%Plug.Conn{path_info: path, script_name: script} = conn, fwd_segments, target, opts) do
    new_path = path -- fwd_segments
    {base, ^new_path} = Enum.split(path, length(path) - length(new_path))
    conn = %{conn | path_info: new_path, script_name: script ++ base} |> target.call(opts)
    %{conn | path_info: path, script_name: script}
  end

  @doc """
  Validates and returns the list of forward path segments.

  Raises RuntimeError plug is already forwarded or path contains
  a dynamic segment.
  """
  def forward_path_segments(path, plug, phoenix_forwards) do
    case Plug.Router.Utils.build_path_match(path) do
      {[], path_segments} ->
        if phoenix_forwards[plug] do
          raise ArgumentError, "`#{inspect plug}` has already been forwarded to. A module can only be forwarded a single time."
        end
        path_segments
      _ ->
        raise ArgumentError, "Dynamic segment `\"#{path}\"` not allowed when forwarding. Use a static path instead."
    end
  end
end
