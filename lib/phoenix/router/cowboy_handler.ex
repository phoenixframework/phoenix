defmodule Phoenix.Router.CowboyHandler do
  @moduledoc false
  @connection Plug.Adapters.Cowboy.Conn

  def init({transport, :http}, req, {plug, opts}) when transport in [:tcp, :ssl] do
    {:upgrade, :protocol, __MODULE__, req, {transport, plug, opts}}
  end

  def upgrade(req, env, __MODULE__, {transport, plug, opts}) do
    conn = @connection.conn(req, transport)
    try do
      case conn = plug.call(conn, opts) do
        %Plug.Conn{private: %{phoenix_upgrade: upgrade}} ->
          {@connection, req}    = conn.adapter
          {:websocket, handler} = upgrade
          :cowboy_websocket.upgrade(req, env, __MODULE__, {handler, conn})
        _ ->
          {@connection, req} = maybe_send(conn, plug).adapter
          {:ok, req, [{:result, :ok} | env]}
      end
    catch
      :error, value ->
        stack = System.stacktrace()
        exception = Exception.normalize(:error, value, stack)
        reason = {{exception, stack}, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
      :throw, value ->
        stack = System.stacktrace()
        reason = {{{:nocatch, value}, stack}, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
      :exit, value ->
        stack = System.stacktrace()
        reason = {value, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
    end
  end

  def terminate(reason, req, stack) do
    :cowboy_req.maybe_reply(stack, req)
    exit(reason)
  end

  defp maybe_send(%Plug.Conn{state: :unset}, _plug),      do: raise Plug.Conn.NotSentError
  defp maybe_send(%Plug.Conn{state: :set} = conn, _plug), do: Plug.Conn.send_resp(conn)
  defp maybe_send(%Plug.Conn{} = conn, _plug),            do: conn
  defp maybe_send(other, plug) do
    raise "Cowboy adapter expected #{inspect plug} to return Plug.Conn but got: #{inspect other}"
  end

  ## Websockets

  def websocket_init(_transport, req, {handler, conn}) do
    {:ok, state} = handler.ws_init(conn)
    {:ok, req, {handler, state}}
  end

  def websocket_handle({:text, text}, req, {handler, state}) do
    state = handler.ws_handle(text, state)
    {:ok, req, {handler, state}}
  end

  def websocket_handle(_other, req, {handler, state}) do
    {:ok, req, {handler, state}}
  end

  def websocket_info({:reply, text}, req, state) do
    {:reply, {:text, text}, req, state}
  end

  def websocket_info(:shutdown, req, state) do
    {:shutdown, req, state}
  end

  def websocket_info(:hibernate, req, {handler, state}) do
    :ok = handler.ws_hibernate(state)
    {:ok, req, state, :hibernate}
  end

  def websocket_info(message, req, {handler, state}) do
    state = handler.ws_info(message, state)
    {:ok, req, {handler, state}}
  end

  def websocket_terminate(reason, _req, {handler, state}) do
    :ok = handler.ws_terminate(reason, state)
  end
end
