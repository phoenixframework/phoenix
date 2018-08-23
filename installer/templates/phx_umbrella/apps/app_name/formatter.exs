[<%= if ecto do %>
  import_deps: [:ecto],<% end %>
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
]
