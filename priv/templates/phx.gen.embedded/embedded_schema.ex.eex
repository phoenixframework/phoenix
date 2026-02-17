defmodule <%= inspect schema.module %> do
  use Ecto.Schema
  import Ecto.Changeset
  alias <%= inspect schema.module %>

  embedded_schema do <%= if !Enum.empty?(schema.types) do %>
<%= Mix.Phoenix.Schema.format_fields_for_schema(schema) %><% end %>
<%= for {_, k, _, _} <- schema.assocs do %>    field <%= inspect k %>, <%= if schema.binary_id do %>:binary_id<% else %>:id<% end %>
<% end %>  end

  @doc false
  def changeset(%<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> cast(attrs, [<%= Enum.map_join(schema.attrs, ", ", &inspect(elem(&1, 0))) %>])
    |> validate_required([<%= Enum.map_join(schema.attrs, ", ", &inspect(elem(&1, 0))) %>])
  end
end
