defmodule Phoenix.Router.Route do
  # This module defines the Route struct that is used
  # throughout Phoenix's router. This struct is private
  # as it contains internal routing information.
  @moduledoc false

  alias Phoenix.Router.Route

  @doc """
  The `Phoenix.Router.Route` struct. It stores:

    * :verb - the HTTP verb as an upcased string
    * :path - the normalized path as string
    * :host - the request host or host prefix
    * :controller - the controller module
    * :action - the action as an atom
    * :helper - the name of the helper as a string (may be nil)
    * :private - the private route info
    * :assigns - the route info
    * :pipe_through - the pipeline names as a list of atoms

  """
  defstruct [:verb, :path, :host, :controller, :action,
             :helper, :private, :pipe_through, :assigns]

  @type t :: %Route{}

  @doc """
  Receives the verb, path, controller, action and helper
  and returns a `Phoenix.Router.Route` struct.
  """
  @spec build(String.t, String.t, String.t | nil, atom, atom, atom | nil, atom, %{}, %{}) :: t
  def build(verb, path, host, controller, action, helper, pipe_through, private, assigns)
      when is_binary(verb) and is_binary(path) and (is_binary(host) or is_nil(host)) and
           is_atom(controller) and is_atom(action) and (is_binary(helper) or is_nil(helper)) and
           is_list(pipe_through) and is_map(private and is_map(assigns)) do
    %Route{verb: verb, path: path, host: host, private: private,
           controller: controller, action: action, helper: helper,
           pipe_through: pipe_through, assigns: assigns}
  end

  @doc """
  Builds the expressions used by the route.
  """
  def exprs(route) do
    {path, binding} = build_path_and_binding(route.path)

    %{path: path,
      host: build_host(route.host),
      binding: binding,
      dispatch: build_dispatch(route, binding)}
  end

  defp build_path_and_binding(path) do
    {params, segments} = Plug.Router.Utils.build_path_match(path)

    binding = Enum.map(params, fn var ->
      {Atom.to_string(var), Macro.var(var, nil)}
    end)

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

  defp build_pipes(route) do
    initial = quote do
      var!(conn)
      |> Plug.Conn.put_private(:phoenix_pipelines, unquote(route.pipe_through))
      |> Plug.Conn.put_private(:phoenix_route, fn conn ->
           opts = unquote(route.controller).init(unquote(route.action))
           unquote(route.controller).call(conn, opts)
         end)
    end

    Enum.reduce(route.pipe_through, initial, &{&1, [], [&2, []]})
  end
end
