defmodule Phoenix.Router.Resource do
  # This module defines the Resource struct that is used
  # throughout Phoenix's router. This struct is private
  # as it contains internal routing information.
  @moduledoc false

  alias Phoenix.Router.Resource

  @default_param_key "id"
  @actions [:index, :edit, :new, :show, :create, :update, :delete]

  @doc """
  The `Phoenix.Router.Resource` struct. It stores:

    * :path - the path as string (not normalized)
    * :param - the param to be used in routes (not normalized)
    * :controller - the controller as an atom
    * :actions - a list of actions as atoms
    * :route - the context for resource routes
    * :member - the context for member routes
    * :collection - the context for collection routes

  """
  defstruct [:path, :actions, :param, :route, :controller, :route, :member, :collection]
  @type t :: %Resource{}

  @doc """
  Builds a plural resource struct.
  """
  def plural(path, controller, options) do
    build(path, controller, options)
  end

  @doc """
  Builds a singular resource struct.
  """
  def singular(path, controller, options) do
    build(path, controller, Keyword.put(options, :singular, true))
  end

  defp build(path, controller, options) when
      is_binary(path) and is_atom(controller) and is_list(options) do
    alias    = Keyword.get(options, :alias)
    param    = Keyword.get(options, :param, @default_param_key)
    name     = Keyword.get(options, :name, Phoenix.Naming.resource_name(controller, "Controller"))
    as       = Keyword.get(options, :as, name)
    singular = Keyword.get(options, :singular)
    private  = Keyword.get(options, :private, %{})
    actions  = extract_actions(options, singular)

    route       = [as: as, private: private]
    collection  = [path: path, as: as, private: private]
    member_path = if singular, do: path, else: Path.join(path, ":#{name}_#{param}")
    member      = [path: member_path, as: as, alias: alias, private: private]

    %Resource{path: path, actions: actions, param: param, route: route,
              member: member, collection: collection, controller: controller}
  end

  defp extract_actions(opts, singular) do
    if only = Keyword.get(opts, :only) do
      @actions -- (@actions -- only)
    else
      default_actions(singular) -- Keyword.get(opts, :except, [])
    end
  end

  defp default_actions(_singular=true), do: @actions -- [:index]
  defp default_actions(_singular),      do: @actions
end
