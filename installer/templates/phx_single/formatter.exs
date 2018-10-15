[
  import_deps: [:phoenix],
  inputs: ["*.{ex,exs}", "{config,lib,priv,test}/**/*.{ex,exs}"]<%= if ecto do %>,
  subdirectories: ["priv/*/migrations"]<% end %>
]
