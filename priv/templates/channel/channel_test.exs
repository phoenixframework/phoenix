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
end
