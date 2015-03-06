use Mix.Config

config :<%= application_name %>, <%= application_module %>.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  cache_static_lookup: false,
  <%= unless skip_brunch? do %>
  watchers: [{Path.expand("node_modules/brunch/bin/brunch"), ["watch"]}],
  <% end %>
  # Watch assets and templates for live-reload changes
  # *Note*: Be careful with wildcards. Larger projects will use higher CPU in dev
  # as the number of files grow. Adjust as necessary.
  live_reload: [Path.expand("priv/static/js/app.js"),
                Path.expand("priv/static/css/app.css"),
                Path.expand("web/templates/**/*.eex")]


# Enables code reloading for development
config :phoenix, :code_reloader, true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
