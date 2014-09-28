defmodule Phoenix.Controller.Flash do
  import Plug.Conn
  alias Plug.Conn

  @http_redir_range 300..308

  @moduledoc """
  Handles One-time messages, often referred to as "Flash" messages.
  Messages can be stored in the session and persisted across redirects for
  notices and alerts about request state.

  ## Examples

      def index(conn, _) do
        render conn, "index", notice: Flash.get(conn, :notice)
      end

      def create(conn, _) do
        conn
        |> Flash.put(:notice, "Created successfully")
        |> redirect("/")
      end

  """

  def init(opts), do: opts

  @doc """
  Clears the Message dict on new requests
  """
  def call(conn = %Conn{private: %{plug_session: _session}}, _) do
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

      iex> conn = %Conn{private: %{plug_session: %{}}}
      iex> match? %Conn{}, Flash.put(conn, :notice, "Welcome Back!")
      true

  """
  def put(conn, key, message) do
    persist(conn, put_in(get(conn), [key], [message | get_all(conn, key)]))
  end

  @doc """
  Returns a message from the Flash

  ## Examples

      iex> Flash.put(conn, :notice, "Hi!") |> Flash.get
      %{notice: "Hi!"}
  """
  def get(conn), do: get_session(conn, :phoenix_messages) || %{}

  @doc """
  Returns a message from the Flash by key

  ## Examples

      iex> Flash.put(conn, :notice, "Hello!") |> Flash.get(:notice)
      "Hello!"

  """
  def get(conn, key) do
     case get_in get(conn), [key] do
      nil -> nil
      [message | _messages] -> message
    end
  end

  @doc """
  Returns a list of messages by key from the Flash

  ## Examples

      iex> conn
      |> Flash.put(:notices, "hello")
      |> Flash.put(:notices, "world")
      |> Flash.get_all(:notices)
      ["hello", "world"]

  """
  def get_all(conn, key) do
    conn
    |> get
    |> get_in([key])
    |> Kernel.||([])
    |> Enum.reverse
  end

  @doc """
  Removes all messages from the for given key, returning a `{msgs, conn}` pair

  ## Examples

      iex> %Conn{}
      |> Flash.put(:notices, "oh noes!")
      |> Flash.put(:notice, "false alarm!")
      |> Flash.pop_all(:notices)
      {["oh noes!", "false alarm!"], %Conn{}}

  """
  def pop_all(conn, key) do
    conn
    |> get_all(key)
    |> case do
      []   -> {[], conn}
      msgs -> {msgs, persist(conn, Dict.drop(get(conn), [key]))}
    end
  end

  @doc """
  Clears all flash messages
  """
  def clear(conn), do: persist(conn, %{})

  defp persist(conn, messages) do
    put_session(conn, :phoenix_messages, messages)
  end
end

