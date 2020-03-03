defmodule Phoenix.Router.Route do
  # This module defines the Route struct that is used
  # throughout Phoenix's router. This struct is private
  # as it contains internal routing information.
  @moduledoc false

  alias Phoenix.Router.Route

  @doc """
  The `Phoenix.Router.Route` struct. It stores:

    * `:verb` - the HTTP verb as an atom
    * `:line` - the line the route was defined
    * `:kind` - the kind of route, one of `:match`, `:forward`
    * `:path` - the normalized path as string
    * `:host` - the request host or host prefix
    * `:plug` - the plug module
    * `:plug_opts` - the plug options
    * `:helper` - the name of the helper as a string (may be nil)
    * `:private` - the private route info
    * `:assigns` - the route info
    * `:pipe_through` - the pipeline names as a list of atoms
    * `:metadata` - general metadata used on telemetry events and route info
    * `:trailing_slash?` - whether or not the helper functions append a trailing slash
  """

  defstruct [:verb, :line, :kind, :path, :host, :plug, :plug_opts,
             :helper, :private, :pipe_through, :assigns, :metadata,
             :trailing_slash?]

  @type t :: %Route{}

  @doc "Used as a plug on forwarding"
  def init(opts), do: opts

  @doc "Used as a plug on forwarding"
  def call(%{path_info: path, script_name: script} = conn, {fwd_segments, plug, opts}) do
    new_path = path -- fwd_segments
    {base, ^new_path} = Enum.split(path, length(path) - length(new_path))
    conn = %{conn | path_info: new_path, script_name: script ++ base}
    conn = plug.call(conn, plug.init(opts))
    %{conn | path_info: path, script_name: script}
  end

  @doc """
  Receives the verb, path, plug, options and helper
  and returns a `Phoenix.Router.Route` struct.
  """
  @spec build(non_neg_integer, :match | :forward, atom, String.t, String.t | nil, atom, atom, atom | nil, atom, map, map, map, boolean) :: t
  def build(line, kind, verb, path, host, plug, plug_opts, helper, pipe_through, private, assigns, metadata, trailing_slash?)
      when is_atom(verb) and (is_binary(host) or is_nil(host)) and
           is_atom(plug) and (is_binary(helper) or is_nil(helper)) and
           is_list(pipe_through) and is_map(private) and is_map(assigns) and
           is_map(metadata) and kind in [:match, :forward] and
           is_boolean(trailing_slash?) do
    %Route{kind: kind, verb: verb, path: path, host: host, private: private,
           plug: plug, plug_opts: plug_opts, helper: helper,
           pipe_through: pipe_through, assigns: assigns, line: line, metadata: metadata,
           trailing_slash?: trailing_slash?}
  end

  @doc """
  Builds the compiled expressions used by the route.
  """
  def exprs(route) do
    {path, binding} = build_path_and_binding(route)

    %{
      path: path,
      host: build_host(route.host),
      verb_match: verb_match(route.verb),
      binding: binding,
      prepare: build_prepare(route, binding),
      path_params: build_path_params(binding),
      dispatch: build_dispatch(route)
    }
  end

  defp verb_match(:*), do: Macro.var(:_verb, nil)
  defp verb_match(verb), do: verb |> to_string() |> String.upcase()

  defp build_path_params(binding), do: {:%{}, [], binding}

  defp build_path_and_binding(%Route{path: path} = route) do
    {params, segments} = case route.kind do
      :forward -> build_path_match(path <> "/*_forward_path_info")
      :match   -> build_path_match(path)
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

  defp build_prepare(route, binding) do
    {match_params, merge_params} = build_params(binding)
    {match_private, merge_private} = build_prepare_expr(:private, route.private)
    {match_assigns, merge_assigns} = build_prepare_expr(:assigns, route.assigns)

    match_all = match_params ++ match_private ++ match_assigns
    merge_all = merge_params ++ merge_private ++ merge_assigns

    if merge_all != [] do
      quote do
        %{unquote_splicing(match_all)} = var!(conn, :conn)
        %{var!(conn, :conn) | unquote_splicing(merge_all)}
      end
    else
      quote do
        var!(conn, :conn)
      end
    end
  end

  defp build_dispatch(%Route{kind: :forward} = route) do
    {_params, fwd_segments} = build_path_match(route.path)

    quote do
      {
        Phoenix.Router.Route,
        {unquote(fwd_segments), unquote(route.plug), unquote(Macro.escape(route.plug_opts))}
      }
    end
  end

  defp build_dispatch(%Route{} = route) do
    quote do
      {unquote(route.plug), unquote(Macro.escape(route.plug_opts))}
    end
  end

  defp build_prepare_expr(_key, data) when data == %{}, do: {[], []}
  defp build_prepare_expr(key, data) do
    var = Macro.var(key, :conn)
    merge = quote(do: Map.merge(unquote(var), unquote(Macro.escape(data))))
    {[{key, var}], [{key, merge}]}
  end

  defp build_params([]), do: {[], []}
  defp build_params(_binding) do
    params = Macro.var(:params, :conn)
    path_params = Macro.var(:path_params, :conn)
    merge_params = quote(do: Map.merge(unquote(params), unquote(path_params)))

    {
      [{:params, params}],
      [{:params, merge_params}, {:path_params, path_params}]
    }
  end

  @doc """
  Validates and returns the list of forward path segments.

  Raises `RuntimeError` if the `plug` is already forwarded or the
  `path` contains a dynamic segment.
  """
  def forward_path_segments(path, plug, phoenix_forwards) do
    case build_path_match(path) do
      {[], path_segments} ->
        if phoenix_forwards[plug] do
          raise ArgumentError, "#{inspect plug} has already been forwarded to. A module can only be forwarded a single time."
        end
        path_segments
      _ ->
        raise ArgumentError, "dynamic segment \"#{path}\" not allowed when forwarding. Use a static path instead."
    end
  end

  if Code.ensure_loaded?(Plug.Router.Utils) do
    defp build_path_match(path) do
      Plug.Router.Utils.build_path_match(path)
    end
  else
    defp build_path_match(path) do
      Plug.Router.Compiler.build_path_match(path)
    end
  end
end
