ExUnit.start
<%= if ecto do %>
<%= adapter_config[:test_setup_all] %>
<% end %>
