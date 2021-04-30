defmodule <%= inspect schema.repo %>.Migrations.Create<%= Macro.camelize(schema.table) %> do
  use <%= inspect schema.migration_module %>

  def change do
    create table(:<%= schema.table %><%= if schema.binary_id do %>, primary_key: false<% end %><%= if schema.prefix do %>, prefix: :<%= schema.prefix %><% end %>) do
<%= if schema.binary_id do %>      add :id, :binary_id, primary_key: true
<% end %><%= for {k, v} <- schema.attrs do %>      add <%= inspect k %>, <%= inspect Mix.Phoenix.Schema.type_for_migration(v) %><%= schema.migration_defaults[k] %>
<% end %><%= for {_, i, _, s} <- schema.assocs do %>      add <%= inspect(i) %>, references(<%= inspect(s) %>, on_delete: :nothing<%= if schema.binary_id do %>, type: :binary_id<% end %>)
<% end %>
      timestamps()
    end
<%= if Enum.any?(schema.indexes) do %><%= for index <- schema.indexes do %>
    <%= index %><% end %>
<% end %>  end
end
