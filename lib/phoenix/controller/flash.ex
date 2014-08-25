defmodule Phoenix.Controller.Flash do
  import Plug.Conn
  alias Plug.Conn

  @http_redir_range 300..308

  @moduledoc """
  Handles One-time messages, often referred to as "Flash" messages.
  Messages can be stored in the session and persisted across redirects for
  notices and alerts about request state.

  Plugged automatically by Phoenix.Controller

  A `Flash` alias is automatically injected when using `Phoenix.Controller`

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
    messages = [message] ++ get_all(conn, key)
    persist(conn, put_in(get(conn), [key], messages))
  end

  @doc """
  Returns a message from the Flash

  ## Examples

      iex> conn = Flash.put(conn, :notice, "Hi!") |> Flash.get
      %{notice: "Hi!"}
      iex> Flash.get(conn, :notice)
      "Welcome Back!"

  """
  def get(conn), do: get_session(conn, :phoenix_messages) || %{}
  def get(conn, key) do
     case get_in get(conn), [key] do
      nil -> nil
      [message | _messages] -> message
    end
  end

  @doc """
  Returns a list of messages from the Flash

  ## Examples

      iex> conn
      iex> |> Flash.put(:notice, "Hello")
      iex> |> Flash.put(:notice, "Hi!")
      iex> |> Flash.get
      %{notice: ["hello", "world"]

  """
  def get_all(conn), do: get_session(conn, :phoenix_messages) || %{}
  def get_all(conn, key) do
    messages = get_in(get(conn), [key]) || []
    Enum.reverse messages
  end

  @doc """
  Removes a message from the Flash, returning a {message, conn} pair

  ## Examples

      iex> conn = Flash.put(%Conn{}, :notice, "Welcome Back!")
      iex> Flash.pop(conn, :notice) |> elem(0)
      "Welcome Back!"

  """
  def pop(conn, key) do
    message = get(conn, key)
    if message do
      conn = persist(conn, Dict.drop(get(conn), [key]))
    end

    {message, conn}
  end

  @doc """
  Removes all messages from the Flash, returning a {messages, conn} pair

  ## Examples

      iex> %Conn{}
      iex> |> Flash.put(:notices, "oh noes!")
      iex> |> Flash.put(:notice, "false alarm!")
      iex> |> Flash.pop_all(:notices) |> elem(0)
      ["oh noes!", "false alarm!"]

  """
  def pop_all(conn, key) do
    messages = get_all(conn, key)
    if messages do
      conn = persist(conn, Dict.drop(get(conn), [key]))
    end

    {messages, conn}
  end

  @doc """
  Clears all flash messages
  """
  def clear(conn), do: persist(conn, %{})

  defp persist(conn, messages) do
    put_session(conn, :phoenix_messages, messages)
  end
end

