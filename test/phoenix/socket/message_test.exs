defmodule Phoenix.Socket.MessageTest do
  use ExUnit.Case, async: true
  doctest Phoenix.Socket.Message

  alias Phoenix.Socket.Message

  describe "inspect/2 custom implementation" do
    test "filters sensitive values in form submit events" do
      message = %Message{
        topic: "lv:1",
        event: "event",
        payload: %{
          "event" => "submit",
          "type" => "form",
          "value" => "username=john&password=secret123&email=john@example.com"
        },
        ref: "1",
        join_ref: "1"
      }

      inspected = inspect(message)

      assert inspected =~ "password=[FILTERED]"
      assert inspected =~ "username=john"
      assert inspected =~ "email=john@example.com"
    end

    test "filters sensitive values at the end of form submit events" do
      message = %Message{
        topic: "lv:1",
        event: "event",
        payload: %{
          "event" => "submit",
          "type" => "form",
          "value" => "username=john&password=secret123"
        },
        ref: "1",
        join_ref: "1"
      }

      inspected = inspect(message)

      assert inspected =~ "username=john"
      assert inspected =~ "password=[FILTERED]\""
    end

    test "handles malformed query strings gracefully" do
      message = %Message{
        topic: "lv:1",
        event: "event",
        payload: %{
          "event" => "submit",
          "type" => "form",
          "value" => "invalid=query=string&password=secret"
        },
        ref: "1",
        join_ref: "1"
      }

      inspected = inspect(message)
      assert is_binary(inspected)
    end
  end
end
