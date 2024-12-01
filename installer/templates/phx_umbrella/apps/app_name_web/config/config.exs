import Config

<%= if @namespaced? || @ecto || @generators do %>
config :<%= @web_app_name %><%= if @namespaced? do %>,
  namespace: <%= @web_namespace %><% end %><%= if @ecto do %>,
  ecto_repos: [<%= @app_module %>.Repo]<% end %><%= if @generators do %>,
  generators: <%= inspect @generators %><% end %>

<% end %># Configures the endpoint
config :<%= @web_app_name %>, <%= @endpoint_module %>,
  url: [host: "localhost"],
  adapter: <%= inspect @web_adapter_module %>,
  render_errors: [
    formats: [<%= if @html do%>html: <%= @web_namespace %>.ErrorHTML, <% end %>json: <%= @web_namespace %>.ErrorJSON],
    layout: false
  ],
  pubsub_server: <%= @app_module %>.PubSub,
  live_view: [signing_salt: "<%= @lv_signing_salt %>"]<%= if @javascript do %>

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  <%= @web_app_name %>: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/<%= @web_app_name %>/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]<% end %><%= if @css do %>

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  <%= @web_app_name %>: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/<%= @web_app_name %>/assets", __DIR__)
  ]<% end %>
