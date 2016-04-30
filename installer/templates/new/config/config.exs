# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

<%= if namespaced? or ecto do %># General application configuration
config :<%= application_name %><%= if namespaced? do %>,
  namespace: <%= application_module %><% end %><%= if ecto do %>,
  ecto_repos: [<%= application_module %>.Repo]<% end %>

<% end %># Configures the endpoint
config :<%= application_name %>, <%= application_module %>.Endpoint,
  url: [host: "localhost"],
  root: Path.dirname(__DIR__),
  secret_key_base: "<%= secret_key_base %>",
  render_errors: [view: <%= application_module %>.ErrorView, accepts: ~w(<%= if html do %>html <% end %>json)],
  pubsub: [name: <%= application_module %>.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
