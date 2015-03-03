defmodule Phoenix.Channel.TestHelper do
  use ExUnit.Case, async: true

  import Phoenix.Channel.Test
  alias Phoenix.PubSub

  defmodule FakeChannel do
    def join(topic, params, socket) do
      send self, {:join_topic, topic}
      send self, {:join_params, params}
      send self, {:join_socket, socket}
    end

    def handle_in(topic, params, socket) do
      send self, {:handle_in_topic, topic}
      send self, {:handle_in_params, params}
      send self, {:handle_in_socket, socket}
    end

    def handle_out(topic, params, socket) do
      send self, {:handle_out_topic, topic}
      send self, {:handle_out_params, params}
      send self, {:handle_out_socket, socket}
    end
  end

  test "build_socket/1 creates a socket with topic" do
    %{topic: topic} = build_socket("foo:bar")

    assert topic == "foo:bar"
  end

  test "build_socket/1 creates a socket with attributes" do
    socket = build_socket(topic: "foo:bar", router: Phoenix.Router)
    %{topic: topic, router: router} = socket

    assert topic == "foo:bar"
    assert router == Phoenix.Router
  end

  test "join/3 calls the channel with socket and params" do
    socket = build_socket("foo:bar")

    join(socket, FakeChannel, %{foo: "bar"})

    assert_received {:join_topic, "foo:bar"}
    assert_received {:join_params, %{foo: "bar"}}
    assert_received {:join_socket, ^socket}
  end

  test "handle_in/3 calls the channel with socket and params" do
    socket = build_socket("foo:bar")

    handle_in(socket, FakeChannel, %{foo: "bar"})

    assert_received {:handle_in_topic, "foo:bar"}
    assert_received {:handle_in_params, %{foo: "bar"}}
    assert_received {:handle_in_socket, ^socket}
  end

  test "handle_out/3 calls the channel with socket and params" do
    socket = build_socket("foo:bar")

    handle_out(socket, FakeChannel, %{foo: "bar"})

    assert_received {:handle_out_topic, "foo:bar"}
    assert_received {:handle_out_params, %{foo: "bar"}}
    assert_received {:handle_out_socket, ^socket}
  end

  test "assert_socket_broadcasted/2" do
    defmodule BroadcastChannel do
      use Phoenix.Channel

      def join(_, _, socket), do: {:ok, socket}

      def handle_in(topic, _params, socket) do
        broadcast socket, topic, %{title: "Phoenix rocks"}
      end
    end

    build_socket("foo:bar")
    |> subscribe(:phx_pub)
    |> handle_in(BroadcastChannel)

    assert_socket_broadcasted("foo:bar", %{title: "Phoenix rocks"})
  end

  test "assert_socket_replied/2" do
    defmodule ReplyChannel do
      use Phoenix.Channel

      def join(_, _, socket), do: {:ok, socket}

      def handle_in(topic, _params, socket) do
        reply socket, topic, %{title: "Phoenix rocks"}
      end
    end

    build_socket("foo:bar")
    |> handle_in(ReplyChannel)

    assert_socket_replied("foo:bar", %{title: "Phoenix rocks"})
  end

  test "subscribe/2 sets the sockests pubsub_server and subscribes" do
    socket =
      build_socket("foo:bar")
      |> subscribe(:phx_pub)

    %{pubsub_server: pubsub_server} = socket
    assert pubsub_server == :phx_pub
    assert subscribers(:phx_pub, "foo:bar") == [self]
  end

  def subscribers(server, topic) do
    PubSub.Local.subscribers(Module.concat(server, Local), topic)
  end
end
