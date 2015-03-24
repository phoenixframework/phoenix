defmodule <%= base %>.Repo.Migrations.Create<%= scoped %> do
  use Ecto.Migration

  def change do
    create table(:<%= plural %>) do
<%= for {k, v} <- attrs do %>      add <%= inspect k %>, <%= inspect v %><%= defaults[k] %>
<% end %>
      timestamps
    end
  end
end
