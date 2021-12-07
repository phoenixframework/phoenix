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
      socket = assign(socket, [foo: :baz])
      assert socket.assigns[:foo] == :baz
      assert socket.assigns[:abc] == :def
    end
  end
end
