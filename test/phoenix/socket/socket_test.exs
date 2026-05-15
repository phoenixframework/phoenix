defmodule Phoenix.SocketTest do
  use ExUnit.Case, async: true

  import Phoenix.Socket
  alias Phoenix.Socket.{Message, InvalidMessageError}

  defmodule UserSocket do
    use Phoenix.Socket

    channel "food*", FoodChannel
    channel "foo*", FooChannel

    def connect(_params, socket, _connect_info), do: {:ok, socket}
    def id(_socket), do: nil
  end

  describe "__channel__" do
    test "returns the correct channel handler module" do
      assert {FooChannel, []} == UserSocket.__channel__("foo:1")
      assert {FoodChannel, []} == UserSocket.__channel__("food:1")
      assert nil == UserSocket.__channel__("unknown")
    end
  end

  describe "messages" do
    test "from_map! converts a map with string keys into a %Message{}" do
      msg = Message.from_map!(%{"topic" => "c", "event" => "e", "payload" => "", "ref" => "r"})
      assert msg == %Message{topic: "c", event: "e", payload: "", ref: "r"}
    end

    test "from_map! raises InvalidMessageError when any required key" do
      assert_raise InvalidMessageError, fn ->
        Message.from_map!(%{"event" => "e", "payload" => "", "ref" => "r"})
      end

      assert_raise InvalidMessageError, fn ->
        Message.from_map!(%{"topic" => "c", "payload" => "", "ref" => "r"})
      end

      assert_raise InvalidMessageError, fn ->
        Message.from_map!(%{"topic" => "c", "event" => "e", "ref" => "r"})
      end

      assert_raise InvalidMessageError, fn ->
        Message.from_map!(%{"topic" => "c", "event" => "e"})
      end
    end
  end

  describe "assign/3" do
    test "assigns to socket" do
      socket = %Phoenix.Socket{}
      assert socket.assigns[:foo] == nil
      socket = assign(socket, :foo, :bar)
      assert socket.assigns[:foo] == :bar
    end
  end

  describe "assign/2" do
    test "assigns a map socket" do
      socket = %Phoenix.Socket{}
      assert socket.assigns[:foo] == nil
      socket = assign(socket, %{foo: :bar, abc: :def})
      assert socket.assigns[:foo] == :bar
      assert socket.assigns[:abc] == :def
    end

    test "merges if values exist" do
      socket = %Phoenix.Socket{}
      socket = assign(socket, %{foo: :bar, abc: :def})
      socket = assign(socket, %{foo: :baz})
      assert socket.assigns[:foo] == :baz
      assert socket.assigns[:abc] == :def
    end

    test "merges keyword lists" do
      socket = %Phoenix.Socket{}
      socket = assign(socket, %{foo: :bar, abc: :def})
      socket = assign(socket, foo: :baz)
      assert socket.assigns[:foo] == :baz
      assert socket.assigns[:abc] == :def
    end

    test "accepts functions" do
      socket = %Phoenix.Socket{}
      assert socket.assigns[:foo] == nil
      socket = assign(socket, :foo, :bar)
      assert socket.assigns[:foo] == :bar
      socket = assign(socket, fn %{foo: :bar} -> [baz: :quux] end)
      assert socket.assigns[:baz] == :quux
    end
  end

  describe "drainer_spec/1" do
    defmodule Endpoint do
      use Phoenix.Endpoint, otp_app: :phoenix
    end

    defmodule DrainerSpecSocket do
      use Phoenix.Socket

      def id(_), do: "123"

      def dynamic_drainer_config do
        [
          batch_size: 200,
          batch_interval: 2_000,
          shutdown: 20_000
        ]
      end
    end

    test "loads static drainer config" do
      drainer_spec = [
        batch_size: 100,
        batch_interval: 1_000,
        shutdown: 10_000
      ]

      assert DrainerSpecSocket.drainer_spec(drainer: drainer_spec, endpoint: Endpoint) ==
               {Phoenix.Socket.PoolDrainer,
                {Endpoint, DrainerSpecSocket, [endpoint: Endpoint, drainer: drainer_spec]}}
    end

    test "loads dynamic drainer config" do
      drainer_spec = DrainerSpecSocket.dynamic_drainer_config()

      assert DrainerSpecSocket.drainer_spec(
               drainer: {DrainerSpecSocket, :dynamic_drainer_config, []},
               endpoint: Endpoint
             ) ==
               {Phoenix.Socket.PoolDrainer,
                {Endpoint, DrainerSpecSocket, [endpoint: Endpoint, drainer: drainer_spec]}}
    end

    test "returns ignore if drainer is set to false" do
      assert DrainerSpecSocket.drainer_spec(drainer: false, endpoint: Endpoint) == :ignore
    end
  end

  describe "__info__/2" do
    alias Phoenix.Socket.Broadcast

    test "disconnect broadcast emits close code 1001 so phoenix.js reconnects" do
      # phoenix.js gates `reconnectTimer.scheduleTimeout()` on
      # `closeCode !== 1000`. The default `{:shutdown, :disconnected}`
      # mapping in bandit ≥1.10.4 is 1000, which suppresses reconnect;
      # we pass 1001 ("Going Away") explicitly so the client retries.
      state = make_ref()
      msg = %Broadcast{topic: "t", event: "disconnect", payload: %{}}

      assert {:stop, {:shutdown, :disconnected}, 1001, ^state} =
               Phoenix.Socket.__info__(msg, state)
    end
  end
end
