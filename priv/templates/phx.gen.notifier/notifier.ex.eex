defmodule <%= inspect context.module %> do
  import Swoosh.Email
  alias <%= inspect context.base_module %>.Mailer<%= for message <- notifier_messages do %>

  def deliver_<%= message %>(%{name: name, email: email}) do
    new()
    |> to({name, email})
    |> from({"Phoenix Team", "team@example.com"})
    |> subject("Welcome to Phoenix, #{name}!")
    |> html_body("<h1>Hello, #{name}</h1>")
    |> text_body("Hello, #{name}\n")
    |> Mailer.deliver()
  end<% end %>
end
