defmodule <%= module %> do
  use <%= base %>.Web, :model

  schema <%= inspect plural %> do
<%= for {k, _} <- attrs do %>    field <%= inspect k %>, <%= inspect types[k] %><%= schema_defaults[k] %>
<% end %><%= for {k, _, m, _} <- assocs do %>    belongs_to <%= inspect k %>, <%= m %><%= if(String.ends_with?(inspect(k), "_id"), do: "", else: ", foreign_key: " <> inspect(k) <> "_id") %>
<% end %>
    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [<%= Enum.map_join(attrs, ", ", &inspect(elem(&1, 0))) %>])
    |> validate_required([<%= Enum.map_join(attrs, ", ", &inspect(elem(&1, 0))) %>])
<%= for k <- uniques do %>    |> unique_constraint(<%= inspect k %>)
<% end %>  end
end
