defmodule Phoenix.Endpoint.Cowboy2WebSocket do
  @moduledoc false

  if Code.ensure_loaded?(:cowboy_websocket) do
    @behaviour :cowboy_websocket
  end

  @connection Plug.Adapters.Cowboy2.Conn
  @already_sent {:plug_conn, :sent}

  def init(req, {_module, {endpoint, handler, opts}}) do
    conn = @connection.conn(req)

    try do
      case Phoenix.Transports.WebSocket.connect(conn, endpoint, handler, opts) do
        {:ok, %{adapter: {@connection, req}}, state} ->
          timeout = Keyword.fetch!(opts, :timeout)
          compress = Keyword.fetch!(opts, :compress)
          {:cowboy_websocket, req, {handler, state}, %{idle_timeout: timeout, compress: compress}}

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

  def websocket_init({handler, state}) do
    {:ok, state} = handler.init(state)
    {:ok, {handler, state}}
  end

  def websocket_handle({opcode, payload}, {handler, state}) when opcode in [:text, :binary] do
    handle_reply(handler, handler.handle_in({payload, opcode: opcode}, state))
  end

  def websocket_handle(_other, handler_state) do
    {:ok, handler_state}
  end

  def websocket_info(message, {handler, state}) do
    handle_reply(handler, handler.handle_info(message, state))
  end

  def terminate({:error, :closed}, _req, {handler, state}) do
    handler.terminate(:closed, state)
  end

  def terminate({:remote, :closed}, _req, {handler, state}) do
    handler.terminate(:closed, state)
  end

  def terminate({:remote, code, _}, _req, {handler, state})
      when code in 1000..1003 or code in 1005..1011 or code == 1015 do
    handler.terminate(:closed, state)
  end

  def terminate(:remote, _req, {handler, state}) do
    handler.terminate(:closed, state)
  end

  def terminate(reason, _req, {handler, state}) do
    handler.terminate(reason, state)
  end

  defp handle_reply(handler, {:ok, state}), do: {:ok, {handler, state}}
  defp handle_reply(handler, {:push, data, state}), do: {:reply, data, {handler, state}}
  defp handle_reply(handler, {:reply, _status, data, state}), do: {:reply, data, {handler, state}}
  defp handle_reply(handler, {:stop, _reason, state}), do: {:stop, {handler, state}}
end
