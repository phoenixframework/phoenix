defmodule <%= inspect schema.repo %>.Migrations.Create<%= Macro.camelize(schema.table) %> do
  use <%= inspect schema.migration_module %>

  def change do
    create table(:<%= schema.table %><%= if schema.binary_id || schema.opts[:primary_key] do %>, primary_key: false<% end %><%= if schema.prefix do %>, prefix: :<%= schema.prefix %><% end %>) do
<%= if schema.binary_id do %>      add :<%= primary_key %>, :binary_id, primary_key: true
<% else %><%= if schema.opts[:primary_key] do %>      add :<%= schema.opts[:primary_key] %>, :id, primary_key: true
<% end %><% end %><%= for {k, v} <- schema.attrs do %>      add <%= inspect k %>, <%= inspect Mix.Phoenix.Schema.type_for_migration(v) %><%= schema.migration_defaults[k] %>
<% end %><%= for {_, i, _, s} <- schema.assocs do %>      add <%= inspect(i) %>, references(<%= inspect(s) %>, on_delete: :nothing<%= if schema.binary_id do %>, type: :binary_id<% end %>)
<% end %><%= if scope do %>      add :<%= scope.schema_key %>, <%= if scope.schema_table do %>references(:<%= scope.schema_table %>, type: <%= inspect scope.schema_migration_type %>, on_delete: :delete_all)<% else %><%= inspect scope.schema_migration_type %><% end %>
<% end %>
      timestamps(<%= if schema.timestamp_type != :naive_datetime, do: "type: #{inspect schema.timestamp_type}" %>)
    end<%= if scope do %>

    create index(:<%= schema.table %>, [:<%= scope.schema_key %>])<% end %>
<%= if Enum.any?(schema.indexes) do %><%= for index <- schema.indexes do %>
    <%= index %><% end %>
<% end %>  end
end
