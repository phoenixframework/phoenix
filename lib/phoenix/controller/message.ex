defmodule Phoenix.Controller.Message do
  import Plug.Conn
  import Phoenix.Controller.Connection
  alias Plug.Conn

  def init(opts), do: opts

  @doc """
  Clears the Message dict on new requests
  """
  def call(conn = %Conn{private: %{plug_session: _session}}, _) do
    conn = fetch_session(conn)
    conn = persist(conn, get_session(conn, :phoenix_messages) || %{})

    register_before_send conn, fn conn ->
      if redirecting?(conn) do
        conn
      else
        persist(conn, %{})
      end
    end
  end
  def call(conn, _), do: conn

  def put(conn, key, message) do
    put_in(conn.private[:phoenix_messages][key], message) |> persist
  end

  def get(conn, key) do
    get_in conn.private[:phoenix_messages], [key]
  end

  def pop(conn, key) do
    message = get(conn, key)
    if message do
      conn = persist(conn, Dict.drop(conn.private[:phoenix_messages], [key]))
    end

    {message, conn}
  end

  defp persist(conn) do
    persist(conn, conn.private[:phoenix_messages])
  end
  defp persist(conn, messages) do
    conn = assign_private(conn, :phoenix_messages, messages)
    put_session(conn, :phoenix_messages, conn.private[:phoenix_messages])
  end
end
