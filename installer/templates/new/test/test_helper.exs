ExUnit.start
<%= if ecto do %>
Mix.Task.run "ecto.create", ["--quiet"]
Mix.Task.run "ecto.migrate", ["--quiet"]
<%= adapter_config[:test_begin] %>
<% end %>
