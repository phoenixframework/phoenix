defmodule Phoenix.Endpoint.CowboyWebsocket do
  @moduledoc false
  @behaviour :cowboy_websocket_handler

  def call(conn, args) do
    resume(conn, :cowboy_websocket, :upgrade, args)
  end

  def resume(conn, module, fun, args) do
    try do
      apply(module, fun, args)
    catch
      kind, [{:reason, reason}, {:mfa, _mfa}, {:stacktrace, stack} | _rest] ->
        reason = format_reason(kind, reason, stack)
        exit({reason, {__MODULE__, :call, [conn, []]}})
    else
      {:suspend, module, fun, args} ->
        {:suspend, __MODULE__, :resume, [conn, module, fun, args]}
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

  def websocket_init(_transport, req, {handler, conn}) do
    {:ok, state, timeout} = handler.ws_init(conn)
    {:ok, :cowboy_req.compact(req), {handler, state}, timeout}
  end

  def websocket_handle({opcode = :text, payload}, req, {handler, state}) do
    handle_reply req, handler, handler.ws_handle(opcode, payload, state)
  end
  def websocket_handle({opcode = :binary, payload}, req, {handler, state}) do
    handle_reply req, handler, handler.ws_handle(opcode, payload, state)
  end
  def websocket_handle(_other, req, {handler, state}) do
    {:ok, req, {handler, state}}
  end

  def websocket_info(message, req, {handler, state}) do
    handle_reply req, handler, handler.ws_info(message, state)
  end

  def websocket_terminate({:error, :closed}, _req, {handler, state}) do
    handler.ws_close(state)
    :ok
  end
  def websocket_terminate({:remote, code, _}, _req, {handler, state})
    when code in 1000..1003
    or code in 1005..1011
    or code == 1015 do

    handler.ws_close(state)
    :ok
  end
  def websocket_terminate(reason, _req, {handler, state}) do
    handler.ws_terminate(reason, state)
    :ok
  end

  defp handle_reply(req, handler, {:ok, new_state}) do
    {:ok, req, {handler, new_state}}
  end
  defp handle_reply(req, handler, {:reply, {opcode, payload}, new_state}) do
    {:reply, {opcode, payload}, req, {handler, new_state}}
  end
end
