# <%= app_module %>

To start your Phoenix server:

  * Install dependencies with `mix deps.get`<%= if ecto do %>
  * Create and migrate your database with `mix ecto.setup`<% end %><%= if webpack do %>
  * Install Node.js dependencies with `cd assets && npm install`<% end %>
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
