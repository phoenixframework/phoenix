defmodule Phoenix.Controller.Flash do
  import Plug.Conn
  alias Plug.Conn

  @http_redir_range 300..308

  def init(opts), do: opts

  @doc """
  Clears the Message dict on new requests
  """
  def call(conn = %Conn{private: %{plug_session: _session}}, _) do
    conn = persist(conn, get_session(conn, :phoenix_messages) || %{})

    register_before_send conn, fn
      conn = %Conn{status: stat} when stat in @http_redir_range -> conn
      conn -> clear(conn)
    end
  end
  def call(conn, _), do: conn

  @doc """
  Persists a message in the Flash, within the current session

  Returns the updated Conn

  ## Examples

      iex> Flash.put(conn, :notice, "Welcome Back!")
      %Conn{...}

  """
  def put(conn, key, message) do
    put_in(conn.private[:phoenix_messages][key], message) |> persist
  end

  @doc """
  Returns a message from the Flash

  ## Examples

      iex> Flash.get(conn)
      %{notice: "Welcome Back!"}

      iex> Flash.get(conn, :notice)
      "Welcome Back!"

  """
  def get(conn), do: conn.private[:phoenix_messages]
  def get(conn, key) do
    get_in conn.private[:phoenix_messages], [key]
  end

  @doc """
  Removes a message from the Flash, returning a {message, conn} pair

  ## Examples

      iex> Flash.pop(conn, :notice)
      {"Welcome Back!", %Conn{...}}

  """
  def pop(conn, key) do
    message = get(conn, key)
    if message do
      conn = persist(conn, Dict.drop(get(conn), [key]))
    end

    {message, conn}
  end

  @doc """
  Clears all flash messages
  """
  def clear(conn), do: persist(conn, %{})

  defp persist(conn) do
    persist(conn, get(conn))
  end
  defp persist(conn, messages) do
    conn = assign_private(conn, :phoenix_messages, messages)
    put_session(conn, :phoenix_messages, conn.private[:phoenix_messages])
  end
end

