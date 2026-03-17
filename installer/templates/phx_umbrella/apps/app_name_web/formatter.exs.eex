[
  import_deps: [:phoenix],<%= if @html do %>
  plugins: [Phoenix.LiveView.HTMLFormatter],<% end %>
  inputs: [<%= if @html do %>"*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}"<% else %>"*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"<% end %>]
]
