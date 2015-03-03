defmodule Phoenix.Channel.Test do
  import ExUnit.Assertions
  alias Phoenix.Socket

  @moduledoc """
  Conveniences for testing Phoenix Channels.

  Includes functions for creating sockets, working with channels, and asserting
  that a socket sent expected payloads. You'll typically want to import
  `Phoenix.Channel.Test`

  ## Examples

      defmodule MyApp.RoomChannelTest do
        use ExUnit.Case
        import Phoenix.Channel.Test
        alias MyApp.RoomChannel

        test "room:new_chat broadcasts a new chat" do
          build_socket("room:new_chat")
          |> handle_in(RoomChannel)

          # Code that creates a chat

          assert_socket_broadcasted("room:new_chat", %{user: "person"})
        end

        test "room:user_info replies with the user's info" do
          build_socket(topic: "room:user_info")
          |> handle_in(RoomChannel)

          assert_socket_replied("room:user_info", %{name: "Gumbi", admin: true})
        end
      end

  """

  @doc """
  Returns a socket ready for testing.

  You can pass it a map to override socket attributes or just a binary to set
  the topic and keep the default socket options.

  ## Examples

      # returns a socket with topic "room:new_chat"
      build_socket("room:new_chat")
      # returns a socket with topic "room:new_chat" and router `Router`
      build_socket(topic: "room:new_chat", router: Router)

  """
  def build_socket(topic) when is_binary(topic) do
    build_socket(topic: topic)
  end
  def build_socket(attributes) do
    attributes = attributes |> Enum.into(%{})
    # TODO: Get the App's configured PubSub server and Router
    %Socket{
      pid: self,
      topic: "",
      assigns: []
    }
    |> Map.merge(attributes)
  end

  @doc """
  A convenience method for testing the `join` call to Channels. Makes it easier
  to compose modify sockets before testing the join code.

  ## Example

      build_socket("room:lobby")
      |> join(RoomChannel, %{auth_token: "correct_token"})

  """
  def join(socket, channel, params \\ %{}) do
    channel.join(socket.topic, params, socket)
  end

  @doc """
  A convenience method for testing the `handle_in` call to Channels.

  Like `join` and `handle_out`, this makes it easier to modify sockets before
  doing something with them.

  ## Example

      user = %User{id: 1, name: "Leonard"}

      build_socket("room:user_info")
      |> authenticate_socket(user)
      |> handle_in(RoomChannel)

      def authenticate_socket(socket, user) do
        Phoenix.Socket.assign(socket, :current_user_id, user.id)
      end
  """
  def handle_in(socket, channel, params \\ %{}) do
    channel.handle_in(socket.topic, params, socket)
  end

  @doc """
  A convenience method for testing the `handle_out` call to Channels.

  Like `join` and `handle_in`, this makes it easier to modify sockets before
  doing something with them.

  ## Example

      build_socket("room:user_info")
      |> handle_out(RoomChannel)
  """
  def handle_out(socket, channel, params \\ %{}) do
    channel.handle_out(socket.topic, params, socket)
  end

  @doc """
  Test that a socket broadcasted a message with `topic` to `payload`.

  Remember to subscribe using `subscribe/2` or there will be no broadcast

  ## Examples

      build_socket("room:new_chat")
      |> subscribe(MyApp.PubSub)
      |> handle_in(RoomChannel)

      assert_socket_broadcasted("room:new_chat", %{name: "John Doe"})

  """
  def assert_socket_broadcasted(topic, payload) do
    assert_receive {
      :socket_broadcast,
      %Socket.Message{event: ^topic, payload: ^payload, topic: ^topic}
    }
  end

  @doc """
  The refutation of `assert_socket_broadcasted/2`
  """
  def refute_socket_broadcasted(topic, payload) do
   refute_receive {
      :socket_broadcast,
      %Socket.Message{event: ^topic, payload: ^payload, topic: ^topic}
    }
  end

  @doc """
  Test that a socket broadcasted a message with `topic` to `payload`.

  ## Examples

      build_socket("room:user_info")
      |> handle_in(RoomChannel)

      assert_socket_replied("room:user_info", %{name: "John Doe"})

  """
  def assert_socket_replied(topic, payload) do
    assert_receive {
      :socket_reply,
      %Socket.Message{event: ^topic, payload: ^payload, topic: ^topic}
    }
  end

  @doc """
  The refutation of `assert_socket_replied/2`
  """
  def refute_socket_replied(topic, payload) do
   refute_receive {
      :socket_reply,
      %Socket.Message{event: ^topic, payload: ^payload, topic: ^topic}
    }
  end

  @doc """
  Sets the pubsub_server of the socket and subscribes to it.

  ## Examples

      build_socket("room:user_info")
      |> subscribe(MyApp.PubSub)

  """
  def subscribe(socket, pubsub) do
    socket = socket |> Map.put(:pubsub_server, pubsub)
    Phoenix.PubSub.subscribe(pubsub, self, socket.topic)
    socket
  end
end
