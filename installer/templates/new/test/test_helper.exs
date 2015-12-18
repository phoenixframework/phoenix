ExUnit.start
<%= if ecto do %>
Mix.Task.run "ecto.create", ~w(-r <%= application_module %>.Repo --quiet)
Mix.Task.run "ecto.migrate", ~w(-r <%= application_module %>.Repo --quiet)
<%= adapter_config[:test_begin] %>
<% end %>
