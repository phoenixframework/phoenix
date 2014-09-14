defmodule Phoenix.Plugs.CsrfProtection do
  alias Plug.Conn

  @moduledoc """
  Plug to protect from cross-site request forgery.

  For this plug to work, it expects a session to have been previously fetched.
  If a CSRF token in the session does not previously exist, a CSRF token will
  be generated and put into the session.

  The session's CSRF token will be compared with a token in the params with key
  "csrf-token" or a token in the request headers with key 'X-CSRF-Token'.

  Only POST, PUT, PATCH and DELETE are protected methods. DELETE methods needs
  a token in the request header to be validated since it doesn't accept params.

  Plugged by Phoenix.Router if :csrf_protection in Phoenix.Config is set to true.

  ## Examples

      plug Phoenix.Plugs.CsrfProtection

  """
  @protected_methods ~w(POST PUT PATCH DELETE)

  def init(opts), do: opts

  def call(%Conn{method: method} = conn, _opts) when method in @protected_methods do
    conn = ensure_csrf_token(conn)
    if verified_request?(conn) do
      conn
    else
      raise """
      Invalid authenticity token. Make sure that all your POST, PUT, PATCH and DELETE
      requests include the authenticity token as part of form params or as a
      value in your request's headers with key 'X-CSRF-Token'.
      """
    end
  end

  def call(conn, _opts), do: ensure_csrf_token(conn)

  defp verified_request?(conn) do
    valid_authenticity_token?(conn, conn.params["csrf_token"]) ||
      valid_token_in_header?(conn)
  end

  defp valid_token_in_header?(conn) do
    header_token = "#{Conn.get_req_header(conn, "X-CSRF-Token")}"
    valid_authenticity_token?(conn, header_token)
  end
  defp valid_authenticity_token?(conn, nil), do: false
  defp valid_authenticity_token?(conn, token), do: get_csrf_token(conn) == token

  def get_csrf_token(conn), do: Conn.get_session(conn, :csrf_token)

  #####
  #
  # TOKEN GENERATION

  defp ensure_csrf_token(conn) do
    if get_csrf_token(conn) do
      conn
    else
      Conn.put_session(conn, :csrf_token, generate_token(token_length))
    end
  end

  defp generate_token(n) when is_integer(n) do
    :crypto.strong_rand_bytes(n)
    |> :base64.encode_to_string
    |> to_string
  end

  defp token_length, do: 32
end
