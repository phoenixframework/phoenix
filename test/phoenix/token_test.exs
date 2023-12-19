defmodule Phoenix.TokenTest do
  use ExUnit.Case, async: true
  alias Phoenix.Token

  setup do
    Logger.disable(self())
    :ok
  end

  defstruct [:endpoint]

  defmodule TokenEndpoint do
    def config(:secret_key_base), do: "abc123"
  end

  describe "sign and verify" do
    test "token with string" do
      id = 1
      key = String.duplicate("abc123", 5)
      token = Token.sign(key, "id", id)
      assert Token.verify(key, "id", token) == {:ok, id}
    end

    test "token with connection" do
      id = 1
      token = Token.sign(conn(), "id", id)
      assert Token.verify(conn(), "id", token) == {:ok, id}
    end

    test "token with socket" do
      id = 1
      token = Token.sign(socket(), "id", id)
      assert Token.verify(socket(), "id", token) == {:ok, id}

      id = 1
      token = Token.sign(%__MODULE__{endpoint: TokenEndpoint}, "id", id)
      assert Token.verify(%__MODULE__{endpoint: TokenEndpoint}, "id", token) == {:ok, id}
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
      assert Token.verify(conn(), "id", token, max_age: 0) == {:error, :expired}

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
      seconds_in_day = 24 * 60 * 60
      day_ago_seconds = System.system_time(:second) - seconds_in_day
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

    test "key defaults" do
      signed1 = Token.sign(conn(), "id", 1, signed_at: 0)

      signed2 =
        Token.sign(conn(), "id", 1,
          signed_at: 0,
          key_length: 32,
          key_digest: :sha256,
          key_iterations: 1000
        )

      assert signed1 == signed2
    end
  end

  describe "encrypt and decrypt" do
    test "token with string" do
      id = 1
      key = String.duplicate("abc123", 5)
      token = Token.encrypt(key, "secret", id)
      assert Token.decrypt(key, "secret", token) == {:ok, id}
    end

    test "token with connection" do
      id = 1
      token = Token.encrypt(conn(), "secret", id)
      assert Token.decrypt(conn(), "secret", token) == {:ok, id}
    end

    test "token with socket" do
      id = 1
      token = Token.encrypt(socket(), "secret", id)
      assert Token.decrypt(socket(), "secret", token) == {:ok, id}
    end

    test "fails on missing token" do
      assert Token.decrypt(TokenEndpoint, "secret", nil) == {:error, :missing}
    end

    test "fails on invalid token" do
      token = Token.encrypt(TokenEndpoint, "secret", 1)

      assert Token.decrypt(TokenEndpoint, "secret", "garbage") ==
               {:error, :invalid}

      assert Token.decrypt(TokenEndpoint, "not_secret", token) ==
               {:error, :invalid}
    end

    test "supports max age in seconds" do
      token = Token.encrypt(conn(), "secret", 1)
      assert Token.decrypt(conn(), "secret", token, max_age: 1000) == {:ok, 1}
      assert Token.decrypt(conn(), "secret", token, max_age: -1000) == {:error, :expired}
      assert Token.decrypt(conn(), "secret", token, max_age: 100) == {:ok, 1}
      assert Token.decrypt(conn(), "secret", token, max_age: -100) == {:error, :expired}
      assert Token.decrypt(conn(), "secret", token, max_age: 0) == {:error, :expired}

      token = Token.encrypt(conn(), "secret", 1)
      assert Token.decrypt(conn(), "secret", token, max_age: 0.1) == {:ok, 1}
      :timer.sleep(150)
      assert Token.decrypt(conn(), "secret", token, max_age: 0.1) == {:error, :expired}
    end

    test "supports :infinity for max age" do
      token = Token.encrypt(conn(), "secret", 1)
      assert Token.decrypt(conn(), "secret", token, max_age: :infinity) == {:ok, 1}
    end

    test "supports signed_at in seconds" do
      seconds_in_day = 24 * 60 * 60
      day_ago_seconds = System.system_time(:second) - seconds_in_day
      token = Token.encrypt(conn(), "secret", 1, signed_at: day_ago_seconds)
      assert Token.decrypt(conn(), "secret", token, max_age: seconds_in_day + 1) == {:ok, 1}

      assert Token.decrypt(conn(), "secret", token, max_age: seconds_in_day - 1) ==
               {:error, :expired}
    end

    test "passes key_iterations options to key generator" do
      signed1 = Token.encrypt(conn(), "secret", 1, signed_at: 0, key_iterations: 1)
      signed2 = Token.encrypt(conn(), "secret", 1, signed_at: 0, key_iterations: 2)
      assert signed1 != signed2
    end

    test "passes key_digest options to key generator" do
      signed1 = Token.encrypt(conn(), "secret", 1, signed_at: 0, key_digest: :sha256)
      signed2 = Token.encrypt(conn(), "secret", 1, signed_at: 0, key_digest: :sha512)
      assert signed1 != signed2
    end
  end

  defp socket() do
    %Phoenix.Socket{endpoint: TokenEndpoint}
  end

  defp conn() do
    %Plug.Conn{} |> Plug.Conn.put_private(:phoenix_endpoint, TokenEndpoint)
  end
end
