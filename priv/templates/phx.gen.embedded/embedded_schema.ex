defmodule <%= inspect schema.module %> do
  use Ecto.Schema
  import Ecto.Changeset
  alias <%= inspect schema.module %>

  embedded_schema do
<%= for {k, v} <- schema.types do %>    field <%= inspect k %>, <%= Mix.Phoenix.Schema.type_and_opts_for_schema(v) %><%= schema.defaults[k] %><%= Mix.Phoenix.Schema.maybe_redact_field(k in schema.redacts) %>
<% end %>  end

  @doc false
  def changeset(%<%= inspect schema.alias %>{} = <%= schema.singular %>, attrs) do
    <%= schema.singular %>
    |> cast(attrs, [<%= Enum.map_join(schema.attrs, ", ", &inspect(elem(&1, 0))) %>])
    |> validate_required([<%= Enum.map_join(schema.attrs, ", ", &inspect(elem(&1, 0))) %>])
  end
end
