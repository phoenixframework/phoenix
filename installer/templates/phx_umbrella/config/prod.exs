import Config

<%= if @mailer do %>
# Configure Swoosh API Client
config :swoosh, :api_client, Swoosh.ApiClient.Req

# Disable Swoosh Local Memory Storage
config :swoosh, local: false<% end %>

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
