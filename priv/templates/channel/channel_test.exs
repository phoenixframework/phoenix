defmodule <%= module %>ChannelTest do
  use ExUnit.Case
  import Phoenix.Channel.ChannelTest
  alias <%= module %>

  test "<%= plural %>:lobby does not require authorization" do
    {status, _socket} =
      build_socket("<%= plural %>:lobby")
      |> join(<%= scoped %>Channel)

    assert status == :ok
  end

  test "<%= plural %>:<%= singular %>_id does not require authorization" do
    {status, _socket} =
      build_socket("<%= plural %>:1")
      |> join(<%= scoped %>Channel)

    assert status == :ok
  end

  <%= for event <- events do %>
    test "<%= event %> broadcasts message" do
      message = %{message: "Test this"}

      build_socket("<%= event %>")
      |> subscribe(<%= base %>.PubSub)
      |> handle_out(<%= scoped %>Channel, message)

      assert_socket_broadcasted("<%= event %>", chat_message)
    end
  <% end %>
end
