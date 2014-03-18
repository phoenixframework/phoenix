# defmodule Phoenix.Socket.Handler do
#   @behaviour :cowboy_websocket_handler
#
#   defrecord Socket, conn: nil, pid: nil
#
#   Enum.each [:tcp, :ssl], fn transport ->
#     @doc false
#     def init({unquote(transport), :http}, req, opts) do
#       {:upgrade, :protocol, :cowboy_websocket, req, opts}
#     end
#   end
#
#   @doc """
#   Handles initalization of the websocket
#
#   Possible returns:
#     :ok
#     {:ok, state}
#     {:ok, state, timeout} # Timeout defines how long it waits for activity from the client. Default: infinity.
#   """
#   def websocket_init(transport, req, opts) do
#     {:ok, state} -> {:ok, req, state}
#   end
#
#   @doc """
#   Handles handles recieving data from the client, default implementation does nothing.
#   """
#   def stream(data, req, state) do
#     # decode data as json, only call stream if request is authenticated
#     # grab out "event" and call controller's on/3 handler
#     # parse channel's named params, ie, "messages/:room_id"
#     # mod.stream(data, req, state)
#     # {:ok, req, state}
#   end
#
#   @doc false
#   def websocket_handle({:text, text}, req, state) do
#     # Handle dispatch here
#     case JSON.decode(text) do
#       {:ok, message}       ->
#         channel = message["channel"]
#         event   = message["event"]
#         data    = message["data"]
#
#         do_handle(message["event"], message["data"], state)
#       {:error, _reason, _} -> {:ok, req, state}
#     end
#   end
#   defp do_handle("join", data, state) do
#
#   end
#
#   @doc """
#   Handles handles recieving messages from erlang processes. Default returns
#     {:ok, state}
#   Possible Returns are identical to stream, all replies gets send to the client.
#   """
#   def info(conn, info, state) do
#     {:ok, state}
#   end
#
#   @doc false
#   def websocket_info({:send, frame, state}, req, _state) do
#      {:reply, frame, req, state}
#   end
#   @doc false
#   def websocket_info(:shutdown, req, state) do
#      {:shutdown, req, state}
#   end
#   @doc false
#   def websocket_info(:hibernate, req, state) do
#      {:ok, req, state, :hibernate}
#   end
#
#   @doc false
#   def websocket_info(data, req, state) do
#     info(data, Socket.new(conn: req, pid: self()), state)
#     {:ok, req, state}
#   end
#
#   @doc """
#   This is called right before the websocket is about to be closed.
#   Reason is defined as:
#    {:normal, :shutdown | :timeout}                        # Called when erlang closes connection
#    {:remote, :closed}                                     # Called if the client formally closes connection
#    {:remote, close_code(), binary()}
#    {:error, :badencoding | :badframe | :closed | atom()}  # Called for many reasons: tab closed, connection dropped.
#   """
#   def closed(_reason, req, state) do
#     :ok
#   end
#
#   @doc false
#   def websocket_terminate(reason, req, state) do
#     closed(reason, Socket.new(conn: req), state)
#   end
#
#   @doc """
#   Sends a reply to the socket. Follow the cowboy websocket frame syntax
#   Frame is defined as
#     :close | :ping | :pong
#     {:text | :binary | :close | :ping | :pong, iodata()}
#     {:close, close_code(), iodata()}
#   Options:
#     :state
#     :hibernate # (true | false) if you want to hibernate the connection
#   close_code: 1000..4999
#   """
#   def reply(socket, frame, state \\ []) do
#     send(socket.pid, {:send, frame, state})
#   end
#
#   @doc """
#   Terminates a connection.
#   """
#   def terminate(socket) do
#     send(socket.pid, :shutdown)
#   end
#
#   @doc """
#   Hibernates the socket.
#   """
#   def hibernate(socket) do
#     send(socket.pid, :hibernate)
#   end
# end
#
