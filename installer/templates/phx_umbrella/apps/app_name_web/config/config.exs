<%= if namespaced? || ecto || generators do %>
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
