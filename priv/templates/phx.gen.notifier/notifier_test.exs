defmodule <%= inspect context.module %>Test do
  use ExUnit.Case, async: true
  import Swoosh.TestAssertions

  alias <%= inspect context.module %>.<%= inflections[:alias] %>Notifier<%= for message <- notifier_messages do %>

  test "deliver_<%= message %>/1" do
    user = %{name: "Alice", email: "alice@example.com"}

    <%= inflections[:alias] %>Notifier.deliver_<%= message %>(user)

    assert_email_sent(
      subject: "Welcome to Phoenix, Alice!",
      to: {"Alice", "alice@example.com"},
      text_body: ~r/Hello, Alice/
    )
  end<% end %>
end
