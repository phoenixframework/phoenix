defmodule <%= @web_namespace %>.Emails.UserEmail do
  import Swoosh.Email

  @doc """
  Sends an email to a user.

  ## Examples

       iex> email = <%= @web_namespace %>.Emails.UserEmail.welcome(%{name: "Ada Lovelace", email: "ada.lovelace@example.com"})
       iex> <%= @web_namespace %>.Mailer.deliver(email)

  """
  def welcome(user) do
    new()
    |> to({user.name, user.email})
    |> from({"Phoenix Team", "phoenix.team@example.com"})
    |> subject("Welcome to Phoenix!")
    |> html_body("<h1>Hello, #{user.name}</h1>")
    |> text_body("Hello, #{user.name}\n")
  end
end
