import Config

# Print only warnings and errors during test
config :logger, level: :warning<%= if @mailer do %>

# In test we don't send emails
config :<%= @app_name %>, <%= @app_module %>.Mailer,
  adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false<% end %>

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime<%= if @html do %>

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true<% end %>
  
# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true