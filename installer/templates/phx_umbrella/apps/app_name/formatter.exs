[<%= if @ecto do %>
  import_deps: [:ecto],
  subdirectories: ["priv/*/migrations"],<% end %><%= if @html and Version.match?(System.version(), ">= 1.13.4") do %>
  plugins: [Phoenix.LiveView.HTMLFormatter],<% end %>
  inputs: [<%= if @html and Version.match?(System.version(), ">= 1.13.4") do %>"*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"<% else %>"*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"<% end %><%= if @ecto do %>, "priv/*/seeds.exs"<% end %>]
]
