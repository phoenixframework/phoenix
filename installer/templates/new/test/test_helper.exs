ExUnit.start
<%= if ecto do %>
Mix.Task.run "ecto.create", ["--quiet"]
Mix.Task.run "ecto.migrate", ["--quiet"]
Ecto.Adapters.SQL.begin_test_transaction(<%= application_module %>.Repo)
<% end %>
