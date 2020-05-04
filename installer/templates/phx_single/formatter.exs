[
  import_deps: [<%= if ecto do %>:ecto, <% end %>:phoenix],<%= if ecto do %>
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]<% else %>
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]<% end %>
]
