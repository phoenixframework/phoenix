defmodule <%= inspect schema.module %> do
  use Ecto.Schema

  schema <%= inspect schema.table %> do
<%= for {k, _} <- schema.attrs do %>    field <%= inspect k %>, <%= inspect schema.types[k] %><%= schema.defaults[k] %>
<% end %><%= for {k, _, m, _} <- schema.assocs do %>    belongs_to <%= inspect k %>, <%= m %><%= if(String.ends_with?(inspect(k), "_id"), do: "", else: ", foreign_key: " <> inspect(k) <> "_id") %>
<% end %>
    timestamps()
  end
end
