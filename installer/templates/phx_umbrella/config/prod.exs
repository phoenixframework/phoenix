import Config

<%= if @mailer do %>
# Configures Swoosh API Client
config :swoosh, :api_client, Swoosh.ApiClient.Finch<% end %>

# Do not print debug messages in production
config :logger, level: :info
