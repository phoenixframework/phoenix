<%= if @namespaced? || @ecto do %># Configure Mix tasks and generators
config :<%= @app_name %><%= if @namespaced? do %>,
  namespace: <%= @app_module %><% end %><%= if @ecto do %>,
  ecto_repos: [<%= @app_module %>.Repo]<% end %><% end %><%= if @mailer do %>

# Configures the mailer.
# Check https://hexdocs.pm/swoosh for different adapters.
config :<%= @app_name %>, <%= @app_module %>.Mailer, adapter: Swoosh.Adapters.SMTP

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false<% end %>
