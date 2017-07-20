defmodule <%= base %>.Repo.Migrations.Create<%= scoped %> do
  use Ecto.Migration

  def change do
    create table(:<%= plural %><%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %><%= for {k, v} <- attrs do %>      add <%= inspect k %>, <%= inspect v %><%= migration_defaults[k] %>
<% end %><%= for {_, i, _, s} <- assocs do %>      add <%= if(String.ends_with?(inspect(i), "_id"), do: inspect(i), else: inspect(i) <> "_id") %>, references(<%= inspect(s) %>, on_delete: :nothing<%= if binary_id do %>, type: :binary_id<% end %>)
<% end %>
      timestamps()
    end<%= if length(indexes) > 0 do %>

    <%= Enum.join(indexes, "\n    ") %><% end %>
  end
end
