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
    * `:kind` - the kind of route, either `:match` or `:forward`
    * `:path` - the normalized path as string
    * `:hosts` - the list of request hosts or host prefixes
    * `:plug` - the plug module
    * `:plug_opts` - the plug options
    * `:helper` - the name of the helper as a string (may be nil)
    * `:private` - the private route info
    * `:assigns` - the route info
    * `:pipe_through` - the pipeline names as a list of atoms
    * `:metadata` - general metadata used on telemetry events and route info
    * `:trailing_slash?` - whether or not the helper functions append a trailing slash
    * `:warn_on_verify?` - whether or not to warn on route verification
  """

  defstruct [
    :verb,
    :line,
    :kind,
    :path,
    :hosts,
    :plug,
    :plug_opts,
    :helper,
    :private,
    :pipe_through,
    :assigns,
    :metadata,
    :trailing_slash?,
    :warn_on_verify?
  ]

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
  @spec build(
          non_neg_integer,
          :match | :forward,
          atom,
          String.t(),
          String.t() | nil,
          atom,
          atom,
          atom | nil,
          list(atom),
          map,
          map,
          map,
          boolean,
          boolean
        ) :: t
  def build(
        line,
        kind,
        verb,
        path,
        hosts,
        plug,
        plug_opts,
        helper,
        pipe_through,
        private,
        assigns,
        metadata,
        trailing_slash?,
        warn_on_verify?
      )
      when is_atom(verb) and is_list(hosts) and
             is_atom(plug) and (is_binary(helper) or is_nil(helper)) and
             is_list(pipe_through) and is_map(private) and is_map(assigns) and
             is_map(metadata) and kind in [:match, :forward] and
             is_boolean(trailing_slash?) do
    %Route{
      kind: kind,
      verb: verb,
      path: path,
      hosts: hosts,
      private: private,
      plug: plug,
      plug_opts: plug_opts,
      helper: helper,
      pipe_through: pipe_through,
      assigns: assigns,
      line: line,
      metadata: metadata,
      trailing_slash?: trailing_slash?,
      warn_on_verify?: warn_on_verify?
    }
  end

  @doc """
  Builds the compiled expressions used by the route.
  """
  def exprs(route) do
    {path, binding} = build_path_and_binding(route)

    %{
      path: path,
      binding: binding,
      dispatch: build_dispatch(route),
      hosts: build_host_match(route.hosts),
      path_params: build_path_params(binding),
      prepare: build_prepare(route),
      verb_match: verb_match(route.verb)
    }
  end

  def build_host_match([]), do: [Plug.Router.Utils.build_host_match(nil)]

  def build_host_match([_ | _] = hosts) do
    for host <- hosts, do: Plug.Router.Utils.build_host_match(host)
  end

  defp verb_match(:*), do: Macro.var(:_verb, nil)
  defp verb_match(verb), do: verb |> to_string() |> String.upcase()

  defp build_path_params(binding), do: {:%{}, [], binding}

  defp build_path_and_binding(%Route{path: path} = route) do
    {_params, segments} =
      case route.kind do
        :forward -> Plug.Router.Utils.build_path_match(path <> "/*_forward_path_info")
        :match -> Plug.Router.Utils.build_path_match(path)
      end

    rewrite_segments(segments)
  end

  # We rewrite segments to use consistent variable naming as we want to group routes later on.
  defp rewrite_segments(segments) do
    {segments, {binding, _counter}} =
      Macro.prewalk(segments, {[], 0}, fn
        {name, _meta, nil}, {binding, counter}
        when is_atom(name) and name != :_forward_path_info ->
          var = Macro.var(:"arg#{counter}", __MODULE__)
          {var, {[{Atom.to_string(name), var} | binding], counter + 1}}

        other, acc ->
          {other, acc}
      end)

    {segments, Enum.reverse(binding)}
  end

  defp build_prepare(route) do
    {match_params, merge_params} = build_params()
    {match_private, merge_private} = build_prepare_expr(:private, route.private)
    {match_assigns, merge_assigns} = build_prepare_expr(:assigns, route.assigns)

    match_all = match_params ++ match_private ++ match_assigns
    merge_all = merge_params ++ merge_private ++ merge_assigns

    quote do
      %{unquote_splicing(match_all)} = var!(conn, :conn)
      %{var!(conn, :conn) | unquote_splicing(merge_all)}
    end
  end

  defp build_prepare_expr(_key, data) when data == %{}, do: {[], []}

  defp build_prepare_expr(key, data) do
    var = Macro.var(key, :conn)
    merge = quote(do: Map.merge(unquote(var), unquote(Macro.escape(data))))
    {[{key, var}], [{key, merge}]}
  end

  defp build_dispatch(%Route{kind: :match, plug: plug, plug_opts: plug_opts}) do
    quote do
      {unquote(plug), unquote(Macro.escape(plug_opts))}
    end
  end

  defp build_dispatch(%Route{
         kind: :forward,
         plug: plug,
         plug_opts: plug_opts,
         metadata: metadata
       }) do
    quote do
      {
        Phoenix.Router.Route,
        {unquote(metadata.forward), unquote(plug), unquote(Macro.escape(plug_opts))}
      }
    end
  end

  defp build_params() do
    params = Macro.var(:params, :conn)
    path_params = Macro.var(:path_params, :conn)

    merge_params =
      quote(do: Phoenix.Router.Route.merge_params(unquote(params), unquote(path_params)))

    {
      [{:params, params}],
      [{:params, merge_params}, {:path_params, path_params}]
    }
  end

  @doc """
  Merges params from router.
  """
  def merge_params(%Plug.Conn.Unfetched{}, path_params), do: path_params
  def merge_params(params, path_params), do: Map.merge(params, path_params)
end
