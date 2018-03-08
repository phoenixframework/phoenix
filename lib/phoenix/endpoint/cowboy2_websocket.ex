defmodule Phoenix.Endpoint.Cowboy2WebSocket do
  # Implementation of the WebSocket transport for Cowboy.
  @moduledoc false

  if Code.ensure_loaded?(:cowboy_websocket) do
    @behaviour :cowboy_websocket
  end

  @connection Plug.Adapters.Cowboy2.Conn
  @already_sent {:plug_conn, :sent}

  def init(req, {module, opts}) do
    conn = @connection.conn(req)
    opts = Tuple.append(opts, req.pid)
    try do
      case module.init(conn, opts) do
        {:ok, %{adapter: {@connection, req}}, {_module, {_socket, opts} = args}} ->
          timeout = Keyword.fetch!(opts, :timeout)
          {:cowboy_websocket, req, {module, args}, %{idle_timeout: timeout}}
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

  def websocket_init({module, args}) do
    {:ok, state, _timeout} = module.ws_init(args)
    {:ok, {module, state}}
  end

  def websocket_handle({opcode = :text, payload}, {handler, state}) do
    handle_reply handler, handler.ws_handle(opcode, payload, state)
  end
  def websocket_handle({opcode = :binary, payload}, {handler, state}) do
    handle_reply handler, handler.ws_handle(opcode, payload, state)
  end
  def websocket_handle(_other, {handler, state}) do
    {:ok, {handler, state}}
  end

  def websocket_info(message, {handler, state}) do
    handle_reply handler, handler.ws_info(message, state)
  end

  def terminate({:error, :closed}, _req, {handler, state}) do
    handler.ws_close(state)
    :ok
  end
  def terminate({:remote, :closed}, _req, {handler, state}) do
    handler.ws_close(state)
    :ok
  end
  def terminate({:remote, code, _}, _req, {handler, state})
      when code in 1000..1003 or code in 1005..1011 or code == 1015 do
    handler.ws_close(state)
    :ok
  end
  def terminate(:remote, _req, {handler, state}) do
    handler.ws_close(state)
    :ok
  end
  def terminate(reason, _req, {handler, state}) do
    handler.ws_close(state)
    handler.ws_terminate(reason, state)
    :ok
  end

  defp handle_reply(handler, {:shutdown, new_state}) do
    {:stop, {handler, new_state}}
  end
  defp handle_reply(handler, {:ok, new_state}) do
    {:ok, {handler, new_state}}
  end
  defp handle_reply(handler, {:reply, {opcode, payload}, new_state}) do
    {:reply, {opcode, payload}, {handler, new_state}}
  end
end
