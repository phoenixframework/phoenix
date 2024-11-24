defmodule <%= inspect(schema.repo) %>.Migrations.Create<%= Macro.camelize(schema.table) %> do
  use <%= inspect(Mix.Phoenix.Migration.module()) %>

  def change do
    create table("<%= schema.table %>"<%= Mix.Phoenix.Migration.table_options(schema) %>) do
<%= Mix.Phoenix.Migration.maybe_specific_primary_key(schema) %><%= Mix.Phoenix.Migration.columns_and_references(schema) %>
      timestamps(<%= Mix.Phoenix.Migration.timestamps_type(schema) %>)
    end<%= Mix.Phoenix.Migration.indexes(schema) %>
  end
end
