[<%= if ecto do %>
  import_deps: [:ecto],
  subdirectories: ["priv/*/migrations"],<% end %>
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
]
