defmodule <%= inspect(schema.module) %> do
  use Ecto.Schema
  import Ecto.Changeset
<%= if schema.prefix do %>
  @schema_prefix :<%= schema.prefix %><% end %><%= if schema.binary_id do %>
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id<% end %>
  schema "<%= schema.table %>" do<%= Mix.Phoenix.Schema.fields_and_associations(schema) %>
    timestamps(<%= Mix.Phoenix.Schema.timestamps_type(schema) %>)
  end

  @doc false
  def changeset(<%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> cast(attrs, [<%= Mix.Phoenix.Schema.cast_fields(schema) %>])
    |> validate_required([<%= Mix.Phoenix.Schema.required_fields(schema) %>])<%= Mix.Phoenix.Schema.changeset_constraints(schema) %>
  end
end
