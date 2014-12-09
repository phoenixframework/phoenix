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
    * :binding - the route bindings
    * :controller - the controller module
    * :action - the action as an atom
    * :helper - the name of the helper as a string (may be nil)
    * :pipe_through - the pipeline names as a list of atoms
    * :path_segments - the path match as quoted segments
    * :host_segments - the host match as quoted segments
    * :pipe_segments - the quoted segments to pipe through

  """
  defstruct [:verb, :path, :host, :binding, :controller, :action, :helper, :pipe_through,
             :path_segments, :host_segments, :pipe_segments]

  @type t :: %Route{}

  @doc """
  Receives the verb, path, controller, action and helper
  and returns a `Phoenix.Router.Route` struct.
  """
  @spec build(String.t, String.t, String.t | nil, atom, atom, atom | nil, atom) :: t
  def build(verb, path, host, controller, action, helper, pipe_through)
      when is_binary(verb) and is_binary(path) and (is_binary(host) or is_nil(host)) and
           is_atom(controller) and is_atom(action) and (is_binary(helper) or is_nil(helper)) and
           is_list(pipe_through) do
    {params, path_segments} = Plug.Router.Utils.build_path_match(path)

    binding = Enum.map(params, fn var ->
      {Atom.to_string(var), Macro.var(var, nil)}
    end)

    %Route{verb: verb, path: path, host: host, binding: binding,
           controller: controller, action: action, helper: helper,
           pipe_through: pipe_through, path_segments: path_segments,
           host_segments: build_host(host), pipe_segments: build_pipes(pipe_through)}
  end

  defp build_host(host) do
    cond do
      is_nil(host)             -> quote do: _
      String.last(host) == "." -> quote do: unquote(host) <> _
      true                     -> host
    end
  end

  defp build_pipes(pipe_through) do
    Enum.reduce(pipe_through, quote(do: var!(conn)), &{&1, [], [&2, []]})
  end
end
