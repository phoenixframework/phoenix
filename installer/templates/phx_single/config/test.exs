import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :<%= @app_name %>, <%= @endpoint_module %>,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "<%= @secret_key_base_test %>",
  server: false<%= if @mailer do %>

# In test we don't send emails.
config :<%= @app_name %>, <%= @app_module %>.Mailer,
  adapter: Swoosh.Adapters.Test<% end %>

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
