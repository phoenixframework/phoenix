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
    * :segments - the route path as quoted segments
    * :binding - the route bindings
    * :controller - the controller module
    * :action - the action as an atom
    * :helper - the named of the helper as a string (may be nil)
    * :pipe_through - the elements to pipe through

  """
  defstruct [:verb, :path, :segments, :binding, :controller, :action, :helper, :pipe_through]
  @type t :: %Route{}

  @doc """
  Receives the verb, path, controller, action and helper
  and returns a `Phoenix.Router.Route` struct.
  """
  @spec build(String.t, String.t, atom, atom, atom, atom) :: t
  def build(verb, path, controller, action, helper, pipe_through)
      when is_binary(verb) and is_binary(path) and is_atom(controller) and
           is_atom(action) and (is_binary(helper) or is_nil(helper)) and
           is_list(pipe_through) do
    {params, segments} = Plug.Router.Utils.build_match(path)

    binding = Enum.map(params, fn var ->
      {Atom.to_string(var), Macro.var(var, nil)}
    end)

    pipes = Enum.reduce(pipe_through, quote(do: var!(conn)), &{&1, [], [&2, []]})

    %Route{verb: verb, path: path, segments: segments, binding: binding,
           controller: controller, action: action, helper: helper,
           pipe_through: pipes}
  end
end
