defmodule <%= module %> do
  use <%= base %>.Web, :model

  schema <%= inspect plural %> do
<%= for {k, _} <- attrs do %>    field <%= inspect k %>, <%= inspect types[k] %><%= schema_defaults[k] %>
<% end %><%= for {k, _, m, _} <- assocs do %>    belongs_to <%= inspect k %>, <%= m %>
<% end %>
    timestamps
  end

  @required_fields [<%= Enum.map_join(attrs, ", ", &inspect(elem(&1, 0))) %>]
  @optional_fields []

  @doc """
  Creates a changeset based on the `struct` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
<%= for k <- uniques do %>    |> unique_constraint(<%= inspect k %>)
<% end %>  end
end
