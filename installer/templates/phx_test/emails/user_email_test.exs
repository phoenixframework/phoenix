defmodule <%= @web_namespace %>.Emails.UserEmailTest do
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  test "welcome/1 sends a welcome email" do
    user = %{name: "Tony", email: "tony.stark@example.com"}

    email = <%= @web_namespace %>.Emails.UserEmail.welcome(user)

    <%= @web_namespace %>.Mailer.deliver(email, [])

    assert_email_sent(
      subject: "Welcome to Phoenix!",
      to: {"Tony", "tony.stark@example.com"},
      text_body: ~r/Hello, Tony/
    )
  end
end
