defmodule <%= base %>.Repo.Migrations.Create<%= scoped %> do
  use Ecto.Migration

  def change do
    create table(:<%= plural %>) do
<%= for {k, v} <- attrs do %>      add <%= inspect k %>, <%= inspect v %><%= defaults[k] %>
<% end %><%= for {_, i, _, s} <- assocs do %>      add <%= inspect i %>, references(<%= inspect(s) %>)
<% end %>
      timestamps
    end
<%= for index <- indexes do %>    <%= index %>
<% end %>
  end
end
