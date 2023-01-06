import Config

<%= if @mailer do %>
# Configures Swoosh API Client
config :swoosh, :api_client, <%= @app_module %>.Finch<% end %>

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
