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
  code_reloader: true,
  cache_static_lookup: false,
  watchers: <%= if brunch do %>[node: ["node_modules/brunch/bin/brunch", "watch"]]<% else %>[]<% end %>

# Watch static and templates for browser reloading.
# *Note*: Be careful with wildcards. Larger projects
# will use higher CPU in dev as the number of files
# grow. Adjust as necessary.
config :<%= application_name %>, <%= application_module %>.Endpoint,
  live_reload: [
    paths: [
      Path.expand("priv/static/js/app.js"),
      Path.expand("priv/static/css/app.css"),
      Path.expand("web/templates/**/*.eex")]]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
