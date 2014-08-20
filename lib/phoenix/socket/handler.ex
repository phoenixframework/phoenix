defmodule Phoenix.Socket.Handler do
  alias Poison, as: JSON

  @behaviour :cowboy_websocket_handler

  alias Phoenix.Socket
  alias Phoenix.Socket.Message
  alias Phoenix.Channel

  defmodule InvalidReturn do
    defexception [:message]
    def exception(msg) do
      %InvalidReturn{message: "Invalid Handler return: #{inspect msg}"}
    end
  end

  @doc """
  Initializes cowboy websocket

  The following transport options can be provided:

    * `{:tcp, :http}` - Insecure transport over http
    * `{:ssl, :http}` - Secure transport over https

  """
  def init({:tcp, :http}, req, opts) do
    {:upgrade, :protocol, :cowboy_websocket, req, opts}
  end
  def init({:ssl, :http}, req, opts) do
    {:upgrade, :protocol, :cowboy_websocket, req, opts}
  end

  @doc """
  Handles initalization of the websocket

  Possible returns:

    * `:ok`
    * `{:ok, req, state}`
    * `{:ok, req, state, timeout}` - Timeout defines how long it waits for activity
                                     from the client. Default: infinity.
  """
  def websocket_init(_transport, req, opts) do
    router = Dict.fetch! opts, :router

    {:ok, req, %Socket{conn: req, pid: self, router: router}}
  end

  @doc """
  Dispatches multiplexed socket message to Router and handles result

  ## Join Event

  "join" events are specially treated.
  When {:ok, socket} is returned from the Channel, the socket is subscribed
  to the channel and authorized to pubsub on the channel/topic pair
  When {:error, socket, reason} is returned, the socket is denied pubsub access

  ## Leave Event

  "leave" events call the channels `leave/2` function only if the socket has
  previously been authorized via `join/2`

  ## Arbitrary Events

  Any other event calls the channel's `event/3` function, with the event
  name as the first argument. Event handlers are only invoked if the socket
  was previously authorized via `join/2`.

  """
  def websocket_handle({:text, text}, _req, socket) do
    msg = Message.parse!(text)

    socket
    |> Socket.set_current_channel(msg.channel, msg.topic)
    |> dispatch(msg.event, msg.message)
  end

  defp dispatch(socket, "join", msg) do
    socket
    |> socket.router.match(:websocket, socket.channel, "join", msg)
    |> handle_result("join")
  end
  defp dispatch(socket, event, msg) do
    if Socket.authenticated?(socket, socket.channel, socket.topic) do
      socket
      |> socket.router.match(:websocket, socket.channel, event, msg)
      |> handle_result(event)
    else
      handle_result({:error, socket, :unauthenticated}, event)
    end
  end

  defp handle_result({:ok, socket}, "join") do
    {:ok, socket.conn, Channel.subscribe(socket, socket.channel, socket.topic)}
  end
  defp handle_result(socket = %Socket{}, "leave") do
    {:ok, socket.conn, Channel.unsubscribe(socket, socket.channel, socket.topic)}
  end
  defp handle_result(socket = %Socket{}, _event) do
    {:ok, socket.conn, socket}
  end
  defp handle_result({:error, socket, _reason}, _event) do
    {:ok, socket.conn, socket}
  end
  defp handle_result(bad_return, event) when event in ["join", "leave"] do
    raise InvalidReturn, message: """
      expected {:ok, %Socket{}} | {:error, %Socket{}, reason} got #{inspect bad_return}
    """
  end
  defp handle_result(bad_return, _event) do
    raise InvalidReturn, message: """
      expected %Socket{} got #{inspect bad_return}
    """
  end

  @doc """
  Handles recieving messages from processes
  """
  def info(_info, _req, state) do
    {:ok, state}
  end

  @doc """
  Receives %Message{} and sends encoded message JSON to client
  """
  def websocket_info(message = %Message{}, req, state) do
    {:reply, {:text, JSON.encode!(message)}, req, state}
  end

  def websocket_info({:reply, frame}, req, state) do
    {:reply, frame, req, state}
  end
  def websocket_info(:shutdown, req, state) do
    {:shutdown, req, state}
  end
  def websocket_info(:hibernate, req, state) do
    {:ok, req, state, :hibernate}
  end

  @doc """
  Handles regular messages to socket process

  Each messages is forward to all socket's authorized channels "info" event
  """
  def websocket_info(data, req, socket) do
    Enum.each socket.channels, fn {channel, topic} ->
      socket
      |> Socket.set_current_channel(channel, topic)
      |> socket.router.match(:websocket, channel, "info", data)
      |> handle_result("info")
    end
    {:ok, req, socket}
  end

  @doc """
  This is called right before the websocket is about to be closed.

  Reason is defined as:

    * `{:normal, :shutdown | :timeout}` - Called when erlang closes connection
    * `{:remote, :closed}`              - Called if client formally closes connection
    * `{:remote, close_code(), binary()}`
    * `{:error, :badencoding | :badframe | :closed | atom()}` - Called for many reasons
                                                          tab closed, conn dropped.
  """
  def websocket_terminate(reason, _req, socket) do
    Enum.each socket.channels, fn {channel, topic} ->
      socket
      |> Socket.set_current_channel(channel, topic)
      |> socket.router.match(:websocket, channel, "leave", reason: reason)
      |> handle_result("leave")
    end
    :ok
  end

  @doc """
  Sends a reply to the socket. Follow the cowboy websocket frame syntax

  Frame is defined as:

    * `:close | :ping | :pong`
    * `{:text | :binary | :close | :ping | :pong, iodata()}`
    * `{:close, close_code(), iodata()}`

  Options:

    * `:state`
    * `:hibernate # (true | false)` if you want to hibernate the connection

  close_code: 1000..4999

  """
  def reply(socket, frame) do
    send(socket.pid, {:reply, frame, socket})
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
