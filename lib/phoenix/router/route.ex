defmodule Phoenix.Router.Route do
  # This module defines the Route struct that is used
  # throughout Phoenix's router.
  @moduledoc false

  alias Phoenix.Router.Route

  @doc """
  The Route struct. It stores:

  * :verb - the HTTP verb as an upcase string
  * :path - the route path as a normalized string 
  * :segments - the route path as quoted segments
  * :params - the parameter names as a list of atoms
  * :controller - ?
  * :action - ?
  * :options - a list of options
  """
  defstruct [:verb, :path, :segments, :params, :controller, :action, :options]

  # TODO: Ensure path is normalized.
  # TODO: Get rid of options.
  def build(verb, path, controller, action, options)
      when is_binary(verb) and is_binary(path) and is_list(options) do
    {params, segments} = Plug.Router.Utils.build_match(path)
    %Route{verb: verb, path: path, segments: segments, params: params,
           controller: controller, action: action, options: options}
  end
end
