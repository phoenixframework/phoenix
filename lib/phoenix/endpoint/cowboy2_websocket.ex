defmodule Phoenix.Endpoint.Cowboy2WebSocket do
  # Implementation of the WebSocket transport for Cowboy.
  @moduledoc false

  if Code.ensure_loaded?(:cowboy_websocket) do
    @behaviour :cowboy_websocket
  end

  alias Phoenix.Transports.WebSocket
  @connection Plug.Adapters.Cowboy2.Conn
  @already_sent {:plug_conn, :sent}

  def init(req, {module, {_, _, _, opts} = args}) do
    conn = @connection.conn(req)

    try do
      case module.init(conn, args) do
        {:ok, %{adapter: {@connection, req}}, args} ->
          timeout = Keyword.fetch!(opts, :timeout)
          compress = Keyword.fetch!(opts, :compress)
          {:cowboy_websocket, req, args, %{idle_timeout: timeout, compress: compress}}
        {:error, %{adapter: {@connection, req}}} ->
          {:error, req}
      end
    catch
      _kind, _reason ->
        {:error, req}
    after
      receive do
        @already_sent -> :ok
      after
        0 -> :ok
      end
    end
  end

  ## Websocket callbacks

  def websocket_init(args) do
    WebSocket.ws_init(args)
  end

  def websocket_handle({opcode = :text, payload}, state) do
    handle_reply WebSocket.ws_handle(opcode, payload, state)
  end
  def websocket_handle({opcode = :binary, payload}, state) do
    handle_reply WebSocket.ws_handle(opcode, payload, state)
  end
  def websocket_handle(_other, state) do
    {:ok, state}
  end

  def websocket_info(message, state) do
    handle_reply WebSocket.ws_info(message, state)
  end

  def terminate({:error, :closed}, _req, state) do
    WebSocket.ws_close(state)
    :ok
  end
  def terminate({:remote, :closed}, _req, state) do
    WebSocket.ws_close(state)
    :ok
  end
  def terminate({:remote, code, _}, _req, state)
      when code in 1000..1003 or code in 1005..1011 or code == 1015 do
    WebSocket.ws_close(state)
    :ok
  end
  def terminate(:remote, _req, state) do
    WebSocket.ws_close(state)
    :ok
  end
  def terminate(reason, _req, state) do
    WebSocket.ws_close(state)
    WebSocket.ws_terminate(reason, state)
    :ok
  end

  defp handle_reply({:shutdown, new_state}) do
    {:stop, new_state}
  end
  defp handle_reply({:ok, new_state}) do
    {:ok, new_state}
  end
  defp handle_reply({:reply, {opcode, payload}, new_state}) do
    {:reply, {opcode, payload}, new_state}
  end
end
