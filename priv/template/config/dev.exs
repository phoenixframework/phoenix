use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :<%= application_name %>, <%= application_module %>.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  cache_static_lookup: false
  watchers: <%= if brunch do %>[{Path.expand("node_modules/brunch/bin/brunch"), ["watch"]}]<% else %>[]<% end %>

# Watch static and templates for browser reloading.
# *Note*: Be careful with wildcards. Larger projects
# will use higher CPU in dev as the number of files
# grow. Adjust as necessary.
config :<%= application_name %>, <%= application_module %>.Endpoint,
  live_reload: [Path.expand("priv/static/js/app.js"),
                Path.expand("priv/static/css/app.css"),
                Path.expand("web/templates/**/*.eex")]

# Enables code reloading for development
config :phoenix, :code_reloader, true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
