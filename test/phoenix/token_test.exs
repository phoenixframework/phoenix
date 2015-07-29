defmodule Phoenix.TokenTest do
  use ExUnit.Case, async: true
  alias Phoenix.Token

  defmodule TokenEndpoint do
    use Phoenix.Endpoint, otp_app: :endpoint_token
  end

  Application.put_env(:endpoint_token, TokenEndpoint, secret_key_base: "abc123")

  setup do 
    {:ok, pid} = TokenEndpoint.start_link
    on_exit(fn ->
      Process.unlink(pid)
      Process.exit(pid, :shutdown)
    end)
  end

  test "happy path" do
    id = 1
    token = Token.sign_token(conn(), "id", id)
    assert id == Token.verify_token(conn(), "id", token)
  end

  test "given a junk token it fails" do
    assert {:error, :invalid} == Token.verify_token(conn(), "garbage", "truck")
  end

  test "verify it works with a socket as well" do
    id = 1
    token = Token.sign_token(socket(), "id", id)
    assert id == Token.verify_token(socket(), "id", token)
  end

  test "overriding expiration" do
    token = Token.sign_token(conn(), "id", 1)
    Stream.timer(40) |> Enum.map(fn (_) ->
      assert {:error, :expired} == Token.verify_token(conn(), "id", token, max_age: 30)
    end)
  end

  test "nil expiration" do
    token = Token.sign_token(conn(), "id", 1)
    Stream.timer(40) |> Enum.map(fn (_) ->
      assert {:error, :expired} != Token.verify_token(conn(), "id", token, max_age: nil)
    end)
  end

  defp socket() do
    %Phoenix.Socket{ endpoint: TokenEndpoint }
  end

  defp conn() do
    %Plug.Conn{} |> Plug.Conn.put_private(:phoenix_endpoint, TokenEndpoint)
  end
end
