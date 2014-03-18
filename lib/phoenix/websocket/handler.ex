defmodule Phoenix.Websocket.Handler do
  @moduledoc """
  This module is a convenience for setting up a basic cowboy websocket.

  ## Example

  Below is an example of an EchoServer websocket.
      defmodule Router do
        use Phoenix.Router
        raw_websocket "echo", Websocket
      end

      defmodule Websocket do
        use Phoenix.Websocket.RawHandler
        def receive(conn, data, state) do
          conn.send(data)
        end
      end

  There are 4 callbacks you can override to handle the common functions of a websocket.
      start(transport, req, opts)
      stream(data, conn, state)
      info(data, conn, state)
      closed(data, conn, state)

  Each function is an alias for the websocket handler functions, for more detailed information on
  connections and what you should/could return from these functions check out the cowboy websocket documentation.
  http://ninenines.eu/docs/en/cowboy/HEAD/manual/cowboy_websocket_handler/

  Things to keep in mind:
  * Connections will die quite often for any number of reasons. Keep your session and state data in another process.
  * This is a raw websocket and it may make sense to look into more robust solutions such as [bullet](https://github.com/extend/bullet)

  """

  defrecord Socket, conn: nil,
                    pid: nil

  defmacro __using__(opts \\ []) do
    router    = Dict.fetch(opts, :router)
    transport = Dict.get(opts, :transport, :tcp)

    unless transport in [:tcp, :ssl] do
      raise "Websocket transport needs to be :tcp or :ssl. Please refer to websocket documentation."
    end

    quote location: :keep do
      @behaviour :cowboy_websocket_handler
      @router unquote(router)

      import unquote(__MODULE__)

      @doc false
      def init({unquote(transport), :http}, req, opts) do
        {:upgrade, :protocol, :cowboy_websocket, req, opts}
      end

      @doc false
      def websocket_init(transport, req, opts) do
        case start(transport, req, opts) do
          {:ok, state}          -> {:ok, req, state}
          {:ok, state, timeout} -> {:ok, req, state, timeout}
          _                     -> {:ok, req, :undefined_state}
        end
      end

      @doc """
      Handles initalization of the websocket

      Possible returns:
        :ok
        {:ok, state}
        {:ok, state, timeout} # Timeout defines how long it waits for activity from the client. Default: infinity.
      """
      def start(_transport, req, _opts) do
        {:ok, req, Socket.new(conn: req, pid: self)}
      end

      @doc """
      Handles handles recieving data from the client, default implementation does nothing.
      """
      def stream(data, req, state) do
        {:ok, req, state}
      end

      @doc false
      def websocket_handle({:text, text}, req, state) do
        # decode data as json, only call stream if request is authenticated
        # grab out "event" and call controller's on/3 handler
        # parse channel's named params, ie, "messages/:room_id"
        case JSON.decode(text) do
          {:ok, message}       ->
            channel = message["channel"]
            event   = message["event"]
            data    = message["data"]
            apply(@router, :match, [req, :websocket, channel, event, data, state])

          {:error, _reason, _} -> {:ok, req, state}
        end
      end

      @doc """
      Handles handles recieving messages from erlang processes. Default returns
        {:ok, state}
      Possible Returns are identical to stream, all replies gets send to the client.
      """
      def info(conn, info, state) do
        {:ok, state}
      end

      @doc false
      def websocket_info({:send, frame, state}, req, _state) do
        {:reply, frame, req, state}
      end
      @doc false
      def websocket_info(:shutdown, req, state) do
        {:shutdown, req, state}
      end
      @doc false
      def websocket_info(:hibernate, req, state) do
        {:ok, req, state, :hibernate}
      end

      @doc false
      def websocket_info(data, req, state) do
        info(data, req, state)
        {:ok, req, state}
      end

      @doc """
      This is called right before the websocket is about to be closed.
      Reason is defined as:
       {:normal, :shutdown | :timeout}                        # Called when erlang closes connection
       {:remote, :closed}                                     # Called if the client formally closes connection
       {:remote, close_code(), binary()}
       {:error, :badencoding | :badframe | :closed | atom()}  # Called for many reasons: tab closed, connection dropped.
      """
      def closed(_reason, req, state) do
      end

      @doc false
      def websocket_terminate(reason, req, state) do
        closed(reason, req, state)
        :ok
      end

      defoverridable [start: 3, stream: 3, info: 3, closed: 3]
    end
  end

  @doc """
  Sends a reply to the socket. Follow the cowboy websocket frame syntax
  Frame is defined as
    :close | :ping | :pong
    {:text | :binary | :close | :ping | :pong, iodata()}
    {:close, close_code(), iodata()}
  Options:
    :state
    :hibernate # (true | false) if you want to hibernate the connection
  close_code: 1000..4999
  """
  def reply(socket, frame, state \\ []) do
    send(socket.pid, {:send, frame, state})
  end

  @doc """
  Terminates a connection.
  """
  def terminate(socket) do
    send(socket.pid, :shutdown)
  end

  @doc """
  Hibernates the socket.
  """
  def hibernate(socket) do
    send(socket.pid, :hibernate)
  end
end

