defmodule Mix.Phoenix.CustomGeneratorBehaviour do
  @moduledoc """
  This module defines the behavior for custom generators.
  Implement modules that implement this behavior and use with mix phx.gen.live,phx.gen.schema,phx.gen.context to
  extend default generators with project specific types and form components.

  For example if using a postgres user type enums you can use type_for_migration/1 to return the user type as an atom and
  type_and_opts_for_schema/1 to return an Ecto.Enum, values: [] string
  by implementing a custom generator along the lines of MyProject.CustomEnumGenerator passed to mix phx.gen.schema as
  "field:MyProject.CustomEnumGenerator:custom_user_type:list:of:allowed:values"
  """

  @doc """
  Unpack custom generator and it's options.
  Return {key, {:custom, __MODULE__, unpacked_options | nil}}
  """
  @callback validate_attr!(attrs :: tuple) :: {name :: atom, {:custom, provider :: atom, opts :: any}} | {term, term}

  @doc """
  return the string that will be used to populate schema field e.g. a string like "Ecto.Enum, values: [:a,:b,:c]"
  """
  @callback type_and_opts_for_schema(attrs :: any) :: String.t()

  @doc """
  return the ecto migration field type term. e.g. {:enum, [:a,:b,:c]}
  """
  @callback type_for_migration(opts :: any) :: term

  @doc """
  return the default value for the field type used by live view and ecto tests.
  """
  @callback type_to_default(key :: atom, opts :: any, action :: atom) :: any

  @doc """
  return the input/live component used to display this custom field type in a live view form.
  """
  @callback live_form_input(key :: atom, opts :: any) :: String.t() | nil

  @doc """
  used for unpacking a complex type that requires serialization from one or more form params.
  For example if your live_form_input routes to a live component that uses a hidden input field containing json that needs
  to be unpacked before passing to the module's changeset.
  return params if no special processing required.
  """
  @callback hydrate_form_input(key :: atom, params :: Map.t, opts :: any) :: Map.t


  @doc """
  Pass to behavior provider. @see validate_attr!/1
  """
  def validate_attr!(provider, attrs) do
    apply(provider, :validate_attr!, [attrs])
  end

  @doc """
  Pass to behavior provider. @see type_and_opts_for_schema/1
  """
  def type_and_opts_for_schema(provider, opts) do
    apply(provider, :type_and_opts_for_schema, [opts])
  end

  @doc """
  Pass to behavior provider. @see type_for_migration/1
  """
  def type_for_migration(provider, opts) do
    apply(provider, :type_for_migration, [opts])
  end

  @doc """
  Pass to behavior provider. @see `type_to_default/3`
  """
  def type_to_default(provider, key, opts, action) do
    apply(provider, :type_to_default, [key, opts, action])
  end

  @doc """
  Pass to behavior provider. @see live_form_input/2
  """
  def live_form_input(provider, key, opts) do
    apply(provider, :live_form_input, [key, opts])
  end
end
