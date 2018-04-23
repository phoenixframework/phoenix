defmodule Phoenix.Endpoint.CowboyWebSocket do
  # Implementation of the WebSocket transport for Cowboy.
  @moduledoc false

  if Code.ensure_loaded?(:cowboy_websocket_handler) do
    @behaviour :cowboy_websocket_handler
  end

  alias Phoenix.Transports.WebSocket
  @connection Plug.Adapters.Cowboy.Conn
  @already_sent {:plug_conn, :sent}

  def init({transport, :http}, req, {module, args}) when transport in [:tcp, :ssl] do
    {_, _, opts} = args
    conn = @connection.conn(req, transport)

    try do
      case module.init(conn, args) do
        {:ok, %{adapter: {@connection, req}}, args} ->
          timeout = Keyword.fetch!(opts, :timeout)
          {:upgrade, :protocol, __MODULE__, req, {args, timeout}}
        {:error, %{adapter: {@connection, req}}} ->
          {:shutdown, req, :no_state}
      end
    catch
      kind, reason ->
        # Although we are not performing a call, we are using the call
        # function for now so it is properly handled in error reports.
        mfa = {module, :call, [conn, args]}
        {:upgrade, :protocol, __MODULE__, req, {:error, mfa, kind, reason, System.stacktrace}}
    after
      receive do
        @already_sent -> :ok
      after
        0 -> :ok
      end
    end
  end

  def upgrade(_req, _env, __MODULE__, {:error, mfa, kind, reason, stack}) do
    reason = format_reason(kind, reason, stack)
    exit({reason, mfa})
  end

  def upgrade(req, env, __MODULE__, {_, _} = args) do
    resume(:cowboy_websocket, :upgrade, [req, env, __MODULE__, args])
  end

  def terminate(_reason,  _req, _state) do
    :ok
  end

  def resume(module, fun, args) do
    try do
      apply(module, fun, args)
    catch
      kind, [{:reason, reason}, {:mfa, _mfa}, {:stacktrace, stack} | _rest] ->
        reason = format_reason(kind, reason, stack)
        exit({reason, {__MODULE__, :resume, []}})
    else
      {:suspend, module, fun, args} ->
        {:suspend, __MODULE__, :resume, [module, fun, args]}
      _ ->
        # We are forcing a shutdown exit because we want to make
        # sure all transports exits with reason shutdown to guarantee
        # all channels are closed.
        exit(:shutdown)
    end
  end

  defp format_reason(:exit, reason, _), do: reason
  defp format_reason(:throw, reason, stack), do: {{:nocatch, reason}, stack}
  defp format_reason(:error, reason, stack), do: {reason, stack}

  ## Websocket callbacks

  def websocket_init(_transport, req, {args, timeout}) do
    {:ok, state} = WebSocket.ws_init(args)
    {:ok, :cowboy_req.compact(req), state, timeout}
  end

  def websocket_handle({opcode = :text, payload}, req, state) do
    handle_reply req, WebSocket.ws_handle(opcode, payload, state)
  end
  def websocket_handle({opcode = :binary, payload}, req, state) do
    handle_reply req, WebSocket.ws_handle(opcode, payload, state)
  end
  def websocket_handle(_other, req, state) do
    {:ok, req, state}
  end

  def websocket_info(message, req, state) do
    handle_reply req, WebSocket.ws_info(message, state)
  end

  def websocket_terminate({:error, :closed}, _req, state) do
    WebSocket.ws_close(state)
    :ok
  end
  def websocket_terminate({:remote, :closed}, _req, state) do
    WebSocket.ws_close(state)
    :ok
  end
  def websocket_terminate({:remote, code, _}, _req, state)
      when code in 1000..1003 or code in 1005..1011 or code == 1015 do
    WebSocket.ws_close(state)
    :ok
  end
  def websocket_terminate(reason, _req, state) do
    WebSocket.ws_terminate(reason, state)
    :ok
  end

  defp handle_reply(req, {:shutdown, new_state}) do
    {:shutdown, req, new_state}
  end
  defp handle_reply(req, {:ok, new_state}) do
    {:ok, req, new_state}
  end
  defp handle_reply(req, {:reply, {opcode, payload}, new_state}) do
    {:reply, {opcode, payload}, req, new_state}
  end
end
