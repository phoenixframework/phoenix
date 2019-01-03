# Since configuration is shared in umbrella projects, this file
# should only configure the :<%= web_app_name %> application itself
# and only for organization purposes. All other config goes to
# the umbrella root.
use Mix.Config

<%= if namespaced? || ecto || generators do %># General application configuration
config :<%= web_app_name %><%= if namespaced? do %>,
  namespace: <%= web_namespace %><% end %><%= if ecto do %>,
  ecto_repos: [<%= app_module %>.Repo]<% end %><%= if generators do %>,
  generators: <%= inspect generators %><% end %>

<% end %># Configures the endpoint
config :<%= web_app_name %>, <%= endpoint_module %>,
  url: [host: "localhost"],
  secret_key_base: "<%= secret_key_base %>",
  render_errors: [view: <%= web_namespace %>.ErrorView, accepts: ~w(<%= if html do %>html <% end %>json), layout: false],
  pubsub: [name: <%= web_namespace %>.PubSub, adapter: Phoenix.PubSub.PG2]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
