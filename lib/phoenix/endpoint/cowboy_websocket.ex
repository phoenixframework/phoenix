defmodule Phoenix.Endpoint.CowboyWebSocket do
  @moduledoc false
  @behaviour :cowboy_sub_protocol
  @behaviour :cowboy_websocket_handler

  def upgrade(req, env, handler, conn) do
    args = [req, env, __MODULE__, {handler, conn}]
    resume(conn, env, :cowboy_websocket, :upgrade, args)
  end

  def resume(conn, env, mod, fun, args) do
    try do
      apply(mod, fun, args)
    catch
      class, [{:reason, reason}, {:mfa, _mfa}, {:stacktrace, stack} | _rest] ->
        exit(class, reason, stack, conn, env)
    else
      {:ok, _req, _env} = ok ->
        ok
      {:suspend, module, fun, args} ->
        {:suspend, __MODULE__, :resume, [conn, env, module, fun, args]}
      {:stop, _req} = stop ->
        stop
    end
  end

  defp exit(class, reason, stack, conn, env) do
    reason2 = format_reason(class, reason, stack)
    exit({reason2, {__MODULE__, :call, [conn, env]}})
  end

  defp format_reason(:exit, reason, _), do: reason
  defp format_reason(:throw, reason, stack), do: {{:nocatch, reason}, stack}
  defp format_reason(:error, reason, stack), do: {reason, stack}

  def websocket_init(_transport, req, {handler, conn}) do
    {:ok, state} = handler.ws_init(conn)
    {:ok, req, {handler, state}}
  end

  def websocket_handle({opcode = :text, payload}, req, {handler, state}) do
    state = handler.ws_handle(opcode, payload, state)
    {:ok, req, {handler, state}}
  end
  def websocket_handle({opcode = :binary, payload}, req, {handler, state}) do
    state = handler.ws_handle(opcode, payload, state)
    {:ok, req, {handler, state}}
  end
  def websocket_handle(_other, req, {handler, state}) do
    {:ok, req, {handler, state}}
  end

  def websocket_info({:reply, {opcode, payload}}, req, state) do
    {:reply, {opcode, payload}, req, state}
  end
  def websocket_info(:shutdown, req, state) do
    {:shutdown, req, state}
  end
  def websocket_info(:hibernate, req, {handler, state}) do
    :ok = handler.ws_hibernate(state)
    {:ok, req, {handler, state}, :hibernate}
  end
  def websocket_info(message, req, {handler, state}) do
    state = handler.ws_info(message, state)
    {:ok, req, {handler, state}}
  end

  def websocket_terminate(reason, _req, {handler, state}) do
    :ok = handler.ws_terminate(reason, state)
    :ok
  end
end
