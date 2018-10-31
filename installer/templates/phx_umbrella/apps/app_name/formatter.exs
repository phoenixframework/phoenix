[<%= if ecto do %>
  import_deps: [:ecto],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]<% else %>
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]<% end %>
]
