[<%= if @ecto do %>
  import_deps: [:ecto, :ecto_sql],
  subdirectories: ["priv/*/migrations"],<% end %><%= if @html do %>
  plugins: [Phoenix.LiveView.HTMLFormatter],<% end %>
  inputs: [<%= if @html do %>"*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"<% else %>"*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"<% end %><%= if @ecto do %>, "priv/*/seeds.exs"<% end %>]
]
