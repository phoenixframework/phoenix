defmodule Phoenix.SocketTest do
  use ExUnit.Case, async: true

  import Phoenix.Socket
  alias Phoenix.Socket.{Message, InvalidMessageError}

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
  end
end
