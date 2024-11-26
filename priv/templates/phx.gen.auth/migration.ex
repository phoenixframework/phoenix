defmodule <%= inspect schema.repo %>.Migrations.Create<%= Macro.camelize(schema.table) %>AuthTables do
  use Ecto.Migration

  def change do<%= if Enum.any?(migration.extensions) do %><%= for extension <- migration.extensions do %>
    <%= extension %><% end %>
<% end %>
    create table(:<%= schema.table %><%= if schema.binary_id do %>, primary_key: false<% end %>) do
<%= if schema.binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      <%= migration.column_definitions[:email] %>
      add :hashed_password, :string, null: false
      add :confirmed_at, <%= inspect schema.timestamp_type %>

      timestamps(<%= if schema.timestamp_type != :naive_datetime, do: "type: #{inspect schema.timestamp_type}" %>)
    end

    create unique_index(:<%= schema.table %>, [:email])

    create table(:<%= schema.table %>_tokens<%= if schema.binary_id do %>, primary_key: false<% end %>) do
<%= if schema.binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :<%= schema.singular %>_id, references(:<%= schema.table %>, <%= if schema.binary_id do %>type: :binary_id, <% end %>on_delete: :delete_all), null: false
      <%= migration.column_definitions[:token] %>
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(<%= if schema.timestamp_type != :naive_datetime, do: "type: #{inspect schema.timestamp_type}, " %>updated_at: false)
    end

    create index(:<%= schema.table %>_tokens, [:<%= schema.singular %>_id])
    create unique_index(:<%= schema.table %>_tokens, [:context, :token])
  end
end
