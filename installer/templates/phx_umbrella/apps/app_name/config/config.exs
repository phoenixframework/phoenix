<%= if @namespaced? || @ecto do %># Configure Mix tasks and generators
config :<%= @app_name %><%= if @namespaced? do %>,
  namespace: <%= @app_module %><% end %><%= if @ecto do %>,
  ecto_repos: [<%= @app_module %>.Repo]<% end %><% end %><%= if @mailer do %>

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :<%= @app_name %>, <%= @app_module %>.Mailer, adapter: Swoosh.Adapters.Local<% end %>
