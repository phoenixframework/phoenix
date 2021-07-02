import Config

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20<%= if @mailer do %>

# By default, emails will not be sent in localhost.
# Instead they are available at "/dev/mailbox".
# Check the application router for details.
config :<%= @app_name %>, <%= @app_module %>.Mailer,
  adapter: Swoosh.Adapters.Local<% end %>
