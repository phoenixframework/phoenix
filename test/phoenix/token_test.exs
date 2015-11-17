defmodule Phoenix.TokenTest do
  use ExUnit.Case, async: true
  alias Phoenix.Token

  defmodule TokenEndpoint do
    def config(:secret_key_base), do: "abc123"
  end

  test "signes and verifies token with connection" do
    id = 1
    token = Token.sign(conn(), "id", id)
    assert Token.verify(conn(), "id", token) == {:ok, id}
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

  defp conn() do
    %Plug.Conn{} |> Plug.Conn.put_private(:phoenix_endpoint, TokenEndpoint)
  end
end
