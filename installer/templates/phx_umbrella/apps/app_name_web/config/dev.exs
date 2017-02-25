use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :<%= web_app_name %>, <%= endpoint_module %>,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: <%= if brunch do %>[node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
                    cd: Path.expand("../assets", __DIR__)]]<% else %>[]<% end %>

<%= if html do %># Watch static and templates for browser reloading.
config :<%= web_app_name %>, <%= endpoint_module %>,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{lib/<%= web_app_name %>/views/.*(ex)$},
      ~r{lib/<%= web_app_name %>/templates/.*(eex)$}
    ]
  ]

<% end %>
