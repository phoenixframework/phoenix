import Config

# Print only warnings and errors during test
config :logger, level: :warn<%= if @mailer do %>

# In test we don't send emails.
config :<%= @app_name %>, <%= @app_module %>.Mailer,
  adapter: Swoosh.Adapters.Test<% end %>
