# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config<%= if @namespaced? || @ecto || @generators do %>

config :<%= @app_name %><%= if @namespaced? do %>,
  namespace: <%= @app_module %><% end %><%= if @ecto do %>,
  ecto_repos: [<%= @app_module %>.Repo]<% end %><%= if @generators do %>,
  generators: <%= inspect @generators %><% end %><% end %>

# Configures the endpoint
config :<%= @app_name %>, <%= @endpoint_module %>,
  url: [host: "localhost"],
  render_errors: [view: <%= @web_namespace %>.ErrorView, accepts: ~w(<%= if @html do %>html <% end %>json), layout: false],
  pubsub_server: <%= @app_module %>.PubSub,
  live_view: [signing_salt: "<%= @lv_signing_salt %>"]<%= if @mailer do %>

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :<%= @app_name %>, <%= @app_module %>.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false<% end %><%= if @assets do %>

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]<% end %>

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
