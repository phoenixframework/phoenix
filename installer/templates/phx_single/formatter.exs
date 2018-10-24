[
  import_deps: [<%= if ecto do %>:ecto, <% end %>:phoenix],
  inputs: ["*.{ex,exs}", "{config,lib,priv,test}/**/*.{ex,exs}"]<%= if ecto do %>,
  subdirectories: ["priv/*/migrations"]<% end %>
]
