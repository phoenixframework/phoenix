import Config

# Print only warnings and errors during test
config :logger, level: :warn<%= if @mailer do %>

# In test we don't send emails.
config :<%= @app_name %>, <%= @app_module %>.Mailer,
  adapter: Swoosh.Adapters.Test<% end %>

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
