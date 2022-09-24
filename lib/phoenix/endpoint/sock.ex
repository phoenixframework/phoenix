defmodule Phoenix.Endpoint.Sock do
  @moduledoc ~S"""
  Implements callbacks as required by the Sock API.

  Functions primarily as a glue layer between the Sock API & an instance of
  Phoenix.Socket.Transport (as realized by Socket instances within Phoenix). Looks up
  configuration from Phoenix.Endpoint to determine the socket handler to use for a request path.
  """

  @behaviour Sock

  alias Sock.Socket

  @impl Sock
  def init(opts) do
    opts
  end

  @impl Sock
  def negotiate(conn, endpoint) do
    # We only care about websocket handlers here, and they ignore the passed in opts so pass nil
    case endpoint.__handler__(conn, nil) do
      {:websocket, conn, handler, opts} ->
        case Phoenix.Transports.WebSocket.connect(conn, endpoint, handler, opts) do
          {:ok, conn, handler_state} ->
            opts = Keyword.take(opts, [:timeout, :compress])
            {:accept, conn, %{handler: handler, handler_state: handler_state}, opts}

          {:error, conn} ->
            {:refuse, conn, endpoint}
        end

      _non_websocket_handler ->
        {:refuse, conn |> Plug.Conn.send_resp(400, "Not a WebSocket path"), endpoint}
    end
  end

  @impl Sock
  def handle_connection(_socket, %{handler: handler, handler_state: handler_state} = state) do
    {:ok, handler_state} = handler.init(handler_state)
    {:continue, %{state | handler_state: handler_state}}
  end

  @impl Sock
  def handle_text_frame(data, socket, %{handler: handler, handler_state: handler_state} = state) do
    handler.handle_in({data, opcode: :text}, handler_state)
    |> handle_continuation(socket, state)
  end

  @impl Sock
  def handle_binary_frame(data, socket, %{handler: handler, handler_state: handler_state} = state) do
    handler.handle_in({data, opcode: :binary}, handler_state)
    |> handle_continuation(socket, state)
  end

  @impl Sock
  def handle_ping_frame(data, socket, %{handler: handler, handler_state: handler_state} = state) do
    if function_exported?(handler, :handle_control, 2) do
      handler.handle_control({data, opcode: :ping}, handler_state)
      |> handle_continuation(socket, state)
    else
      {:continue, state}
    end
  end

  @impl Sock
  def handle_pong_frame(data, socket, %{handler: handler, handler_state: handler_state} = state) do
    if function_exported?(handler, :handle_control, 2) do
      handler.handle_control({data, opcode: :pong}, handler_state)
      |> handle_continuation(socket, state)
    else
      {:continue, state}
    end
  end

  @impl Sock
  def handle_close({:remote, _code}, _socket, %{handler: handler, handler_state: handler_state}) do
    handler.terminate(:closed, handler_state)
  end

  def handle_close({:local, 1000}, _socket, %{handler: handler, handler_state: handler_state}) do
    handler.terminate(:normal, handler_state)
  end

  def handle_close({:local, 1001}, _socket, %{handler: handler, handler_state: handler_state}) do
    handler.terminate(:shutdown, handler_state)
  end

  def handle_close(reason, _socket, %{handler: handler, handler_state: handler_state}) do
    handler.terminate(reason, handler_state)
  end

  @impl Sock
  def handle_error(error, _socket, %{handler: handler, handler_state: handler_state}) do
    handler.terminate(error, handler_state)
  end

  @impl Sock
  def handle_timeout(_socket, %{handler: handler, handler_state: handler_state}) do
    handler.terminate(:timeout, handler_state)
  end

  @impl Sock
  def handle_info(msg, socket, %{handler: handler, handler_state: handler_state} = state) do
    handler.handle_info(msg, handler_state)
    |> handle_continuation(socket, state)
  end

  defp handle_continuation(reply, socket, state) do
    case reply do
      {:ok, handler_state} ->
        {:continue, %{state | handler_state: handler_state}}

      {:reply, _code, data, handler_state} ->
        send_data(data, socket)
        {:continue, %{state | handler_state: handler_state}}

      {:push, data, handler_state} ->
        send_data(data, socket)
        {:continue, %{state | handler_state: handler_state}}

      {:stop, _reason, handler_state} ->
        {:close, %{state | handler_state: handler_state}}
    end
  end

  defp send_data({:text, data}, socket), do: Socket.send_text_frame(socket, data)
  defp send_data({:binary, data}, socket), do: Socket.send_binary_frame(socket, data)
  defp send_data(:ping, socket), do: Socket.send_ping_frame(socket, "")
  defp send_data({:ping, data}, socket), do: Socket.send_ping_frame(socket, data)
  defp send_data(:pong, socket), do: Socket.send_pong_frame(socket, "")
  defp send_data({:pong, data}, socket), do: Socket.send_pong_frame(socket, data)
end
