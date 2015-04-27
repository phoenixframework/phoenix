defmodule Phoenix.Test.TokenTest do
  use ExUnit.Case, async: true
  alias Phoenix.Token

  defmodule TokenEndpoint do
    use Phoenix.Endpoint, otp_app: :endpoint_token
  end

  Application.put_env(:endpoint_token, TokenEndpoint,
    token_auth: [ secret_key_base: "abc123",
                  encryption_salt: "foobar",
                  signing_salt: "chrismc",
                  max_age: 20 ])

  setup do 
    {:ok, pid} = TokenEndpoint.start_link
    on_exit(fn ->
      Process.unlink(pid)
      Process.exit(pid, :shutdown)
    end)
  end

  test "happy path for the encoder" do
    id = 1
    token = Token.gen_token(conn(), id)
    assert id == Token.verify_token(conn(), token)
  end

  test "given a junk token it fails" do
    assert :error == Token.verify_token(conn(), "garbage")
  end
  test "bad expiration it fails" do
    token = Token.gen_token(conn(), 1)
    Stream.timer(30) |> Enum.map(fn (_) ->
      assert :token_expired == Token.verify_token(conn(), token)
    end)
  end

  test "verify it works with a socket as well" do
    id = 1
    token = Token.gen_token(socket(), id)
    assert id == Token.verify_token(socket(), token)
  end

  defp socket() do
    %Phoenix.Socket{ endpoint: TokenEndpoint }
  end

  defp conn() do
    %Plug.Conn{} |> Plug.Conn.put_private(:phoenix_endpoint, TokenEndpoint)
  end
end
