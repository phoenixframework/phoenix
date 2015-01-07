defmodule Phoenix.Router.Resource do
  # This module defines the Resource struct that is used
  # throughout Phoenix's router. This struct is private
  # as it contains internal routing information.
  @moduledoc false

  alias Phoenix.Router.Resource

  @default_param_key "id"
  @actions [:index, :edit, :new, :show, :create, :update, :destroy]

  @doc """
  The `Phoenix.Router.Resource` struct. It stores:

    * :path - the path as string (not normalized)
    * :param - the param to be used in routes (not normalized)
    * :as - the helper name (not normalized)
    * :controller - the controller as an atom
    * :actions - a list of actions as atoms
    * :member - the context for member routes
    * :collection - the context for collection routes

  """
  defstruct [:path, :actions, :param, :as, :controller, :member]
  @type t :: %Resource{}

  @doc """
  Receives the path, controller and a set of options and
  returns a `Phoenix.Router.Resource` struct.
  """
  def build(path, controller, options) when
      is_binary(path) and is_atom(controller) and is_list(options) do
    actions = extract_actions(options)
    alias   = Keyword.get(options, :alias)
    param   = Keyword.get(options, :param, @default_param_key)
    name    = Keyword.get(options, :name, Phoenix.Naming.resource_name(controller, "Controller"))
    as      = Keyword.get(options, :as, name)

    member  = [path: Path.join(path, ":#{name}_#{param}"), as: as, alias: alias,
               collection_path: path]

    %Resource{path: path, actions: actions, param: param, as: as,
              member: member, controller: controller}
  end

  defp extract_actions(opts) do
    Keyword.get(opts, :only) || (@actions -- Keyword.get(opts, :except, []))
  end
end
