[
  import_deps: [<%= if @ecto do %>:ecto, :ecto_sql, <% end %>:phoenix],<%= if @ecto do %>
  subdirectories: ["priv/*/migrations"],<% end %><%= if @html do %>
  plugins: [Phoenix.LiveView.HTMLFormatter],<% end %>
  inputs: [<%= if @html do %>"*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"<% else %>"*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"<% end %><%= if @ecto do %>, "priv/*/seeds.exs"<% end %>]
]
