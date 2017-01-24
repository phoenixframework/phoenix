defmodule <%= inspect schema_module %> do
  use Ecto.Schema

  schema <%= inspect schema_plural %> do
<%= for {k, _} <- schema_attrs do %>    field <%= inspect k %>, <%= inspect schema_types[k] %><%= schema_defaults[k] %>
<% end %><%= for {k, _, m, _} <- schema_assocs do %>    belongs_to <%= inspect k %>, <%= m %><%= if(String.ends_with?(inspect(k), "_id"), do: "", else: ", foreign_key: " <> inspect(k) <> "_id") %>
<% end %>
    timestamps()
  end
end
