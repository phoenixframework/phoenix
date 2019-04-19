<%= if namespaced? || ecto do %># Configure Mix tasks and generators
config :<%= app_name %><%= if namespaced? do %>,
  namespace: <%= app_module %><% end %><%= if ecto do %>,
  ecto_repos: [<%= app_module %>.Repo]<% end %><% end %>
