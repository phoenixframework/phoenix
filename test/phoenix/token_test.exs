defmodule Phoenix.TokenTest do
  use ExUnit.Case, async: true
  alias Phoenix.Token

  @moduletag :capture_log

  defmodule TokenEndpoint do
    def config(:secret_key_base), do: "abc123"
  end

  test "signes and verifies token with string" do
    id = 1
    key = String.duplicate("abc123", 5)
    token = Token.sign(key, "id", id)
    assert Token.verify(key, "id", token) == {:ok, id}
  end

  test "signes and verifies token with connection" do
    id = 1
    token = Token.sign(conn(), "id", id)
    assert Token.verify(conn(), "id", token) == {:ok, id}
  end

  test "signes and verifies token with socket" do
    id = 1
    token = Token.sign(socket(), "id", id)
    assert Token.verify(socket(), "id", token) == {:ok, id}
  end

  test "fails on missing token" do
    assert Token.verify(TokenEndpoint, "id", nil) == {:error, :missing}
  end

  test "fails on invalid token" do
    token = Token.sign(TokenEndpoint, "id", 1)

    assert Token.verify(TokenEndpoint, "id", "garbage") ==
           {:error, :invalid}
    assert Token.verify(TokenEndpoint, "not_id", token) ==
           {:error, :invalid}
  end

  test "supports max age in seconds" do
    token = Token.sign(conn(), "id", 1)
    assert Token.verify(conn(), "id", token, max_age: 1000) == {:ok, 1}
    assert Token.verify(conn(), "id", token, max_age: -1000) == {:error, :expired}
    assert Token.verify(conn(), "id", token, max_age: 100) == {:ok, 1}
    assert Token.verify(conn(), "id", token, max_age: -100) == {:error, :expired}

    token = Token.sign(conn(), "id", 1)
    assert Token.verify(conn(), "id", token, max_age: 0.1) == {:ok, 1}
    :timer.sleep(150)
    assert Token.verify(conn(), "id", token, max_age: 0.1) == {:error, :expired}
  end

  test "supports :infinity for max age" do
    token = Token.sign(conn(), "id", 1)
    assert Token.verify(conn(), "id", token, max_age: :infinity) == {:ok, 1}
  end

  test "supports signed_at in seconds" do
    seconds_in_day = 24*60*60
    day_ago_seconds = System.system_time(:seconds) - seconds_in_day
    token = Token.sign(conn(), "id", 1, signed_at: day_ago_seconds)
    assert Token.verify(conn(), "id", token, max_age: seconds_in_day + 1) == {:ok, 1}
    assert Token.verify(conn(), "id", token, max_age: seconds_in_day - 1) == {:error, :expired}
  end

  test "passes key_iterations options to key generator" do
    signed1 = Token.sign(conn(), "id", 1, signed_at: 0, key_iterations: 1)
    signed2 = Token.sign(conn(), "id", 1, signed_at: 0, key_iterations: 2)
    assert signed1 != signed2
  end

  test "passes key_digest options to key generator" do
    signed1 = Token.sign(conn(), "id", 1, signed_at: 0, key_digest: :sha256)
    signed2 = Token.sign(conn(), "id", 1, signed_at: 0, key_digest: :sha512)
    assert signed1 != signed2
  end

  test "passes key_length options to key generator" do
    signed1 = Token.sign(conn(), "id", 1, signed_at: 0, key_length: 16)
    signed2 = Token.sign(conn(), "id", 1, signed_at: 0, key_length: 32)
    assert signed1 != signed2
  end

  test "key defaults" do
    signed1 = Token.sign(conn(), "id", 1, signed_at: 0)
    signed2 = Token.sign(conn(), "id", 1, signed_at: 0, key_length: 32, key_digest: :sha256, key_iterations: 1000)
    assert signed1 == signed2
  end

  defp socket() do
    %Phoenix.Socket{endpoint: TokenEndpoint}
  end

  defp conn() do
    %Plug.Conn{} |> Plug.Conn.put_private(:phoenix_endpoint, TokenEndpoint)
  end
end
