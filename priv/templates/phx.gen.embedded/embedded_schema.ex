defmodule <%= inspect(schema.module) %> do
  use Ecto.Schema
  import Ecto.Changeset
  alias <%= inspect(schema.module) %>

  embedded_schema do<%= Mix.Phoenix.Schema.fields_and_associations(schema) %>  end

  @doc false
  def changeset(%<%= inspect(schema.alias) %>{} = <%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> cast(attrs, [<%= Mix.Phoenix.Schema.cast_fields(schema) %>])
    |> validate_required([<%= Mix.Phoenix.Schema.required_fields(schema) %>])<%= Mix.Phoenix.Schema.length_validations(schema) %>
  end
end
