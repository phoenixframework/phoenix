defmodule <%= inspect(schema.repo) %>.Migrations.Create<%= Macro.camelize(schema.table) %> do
  use <%= inspect(Mix.Phoenix.Migration.module()) %>

  def change do
    create table("<%= schema.table %>"<%= if schema.binary_id do %>, primary_key: false<% end %><%= if schema.prefix do %>, prefix: :<%= schema.prefix %><% end %>) do
<%= if schema.binary_id do %>      add :id, :binary_id, primary_key: true
<% end %><%= Mix.Phoenix.Migration.columns_and_references(schema) %>
      timestamps(<%= Mix.Phoenix.Migration.timestamps_type(schema) %>)
    end<%= Mix.Phoenix.Migration.indexes(schema) %>
  end
end
