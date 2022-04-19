[<%= if @html and Version.match?(System.version(), ">= 1.13.4") do %>
  plugins: [Phoenix.LiveView.HTMLFormatter],<% end %>
  inputs: ["mix.exs", "config/*.exs"],
  subdirectories: ["apps/*"]
]
