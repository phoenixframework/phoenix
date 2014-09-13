defmodule Phoenix.Plugs.CsrfProtection do
  alias Plug.Conn
  alias Plug.Session.COOKIE
  alias Phoenix.Config

  @moduledoc """
  Plug to protect from cross-site request forgery. It compares csrf_token in session
  with csrf_token passed in params.

  Plugged by Phoenix.Router if :csrf_protection in Phoenix.Config is set to true.

  ## Examples

      plug Phoenix.Plugs.CsrfProtection

  """
  @protected_methods ~w(POST PUT PATCH DELETE)

  def init(opts), do: opts

  def call(%Conn{method: method} = conn, _opts) when method in @protected_methods do
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

  def call(conn, _opts), do: conn

  def verified_request?(conn) do
    valid_authenticity_token?(conn, conn.params["csrf_token"]) ||
      valid_authenticity_token?(conn, Conn.get_req_header(conn, "X-CSRF-Token"))
  end

  defp valid_authenticity_token?(conn, nil), do: false
  defp valid_authenticity_token?(conn, token), do: get_csrf_token(conn) == token


  defp get_csrf_token(conn), do: Conn.get_session(conn, :csrf_token)

  defp token_length, do: 32
end
