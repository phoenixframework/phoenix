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
        render conn, "index", notice: Flash.flash(conn, :notice)
      end

      def create(conn, _) do
        conn
        |> Flash.put_flash(:notice, "Created successfully")
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
      conn -> clear_flash(conn)
    end
  end
  def call(conn, _), do: conn

  @doc """
  Persists a message in the `Phoenix.Flash`, within the current session

  Returns the updated `%Conn{}`

  ## Examples

      iex> conn = %Conn{private: %{plug_session: %{}}}
      iex> match? %Conn{}, Flash.put_flash(conn, :notice, "Welcome Back!")
      true

  """
  def put_flash(conn, key, message) do
    persist(conn, put_in(flash(conn), [key], message))
  end

  @doc """
  Returns a message from the `Phoenix.Flash`

  ## Examples

      iex> Flash.put_flash(conn, :notice, "Hi!") |> Flash.get
      %{notice: "Hi!"}
  """
  def flash(conn), do: get_session(conn, :phoenix_messages) || %{}

  @doc """
  Returns a message from the `Phoenix.Flash` by key

  ## Examples

      iex> Flash.put_flash(conn, :notice, "Hello!") |> Flash.flash(:notice)
      "Hello!"

  """
  def flash(conn, key) do
     get_in flash(conn), [key]
  end

  @doc """
  Clears all flash messages
  """
  def clear_flash(conn), do: persist(conn, %{})

  defp persist(conn, messages) do
    put_session(conn, :phoenix_messages, messages)
  end
end

