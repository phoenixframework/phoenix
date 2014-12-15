defmodule Phoenix.Endpoint.CowboyWebSocket do
  @moduledoc false
  @behaviour :cowboy_sub_protocol
  @behaviour :cowboy_websocket_handler
  @connection Plug.Adapters.Cowboy.Conn

  def call(%Plug.Conn{private: %{phoenix_upgrade: upgrade}} = conn, env) do
    {@connection, req}    = conn.adapter
    {:websocket, handler} = upgrade
    upgrade(req, env, handler, conn)
  end

  def upgrade(req, env, handler, conn) do
    args = [req, env, __MODULE__, {handler, conn}]
    resume(conn, env, :cowboy_websocket, :upgrade, args)
  end

  def resume(conn, env, mod, fun, args) do
    try do
      apply(mod, fun, args)
    catch
      class, [reason: reason, mfa: {__MODULE__, :websocket_init, 3},
          stacktrace: stack, req: _req, opts: {handler, conn}] ->
        mfa = {handler, :ws_init, [conn]}
        exit(class, reason, stack, mfa, conn, env)
      class, [reason: reason, mfa: {__MODULE__, :websocket_handle, 3},
          stacktrace: stack, msg: {:text, text}, req: _req,
          state: {handler, state}] ->
        mfa = {handler, :ws_handle, [text, state]}
        exit(class, reason, stack, mfa, conn, env)
      class, [reason: reason, mfa: {__MODULE__, :websocket_info, 3},
          stacktrace: stack, msg: :hibernate, req: _req,
          state: {handler, state}] ->
        mfa = {handler, :ws_hibernate, [state]}
        exit(class, reason, stack, mfa, conn, env)
      class, [reason: reason, mfa: {__MODULE__, :websocket_info, 3},
          stacktrace: stack, msg: msg, req: _req, state: {handler, state}] ->
        mfa = {handler, :ws_info, [msg, state]}
        exit(class, reason, stack, mfa, conn, env)
      class, [reason: reason, mfa: {__MODULE__, :websocket_terminate, 3},
          stacktrace: stack, req: _req, state: {handler, state},
          terminate_reason: terminate_reason] ->
        mfa = {handler, :ws_terminate, [terminate_reason, state]}
        exit(class, reason, stack, mfa, conn, env)
    else
      {:ok, _req, _env} = ok ->
        ok
      {:suspend, module, fun, args} ->
        {:suspend, __MODULE__, :resume, [conn, env, module, fun, args]}
      {:stop, _req} = stop ->
        stop
    end
  end

  defp exit(class, reason, stack, mfa, conn, env) do
    reason2 = {format_reason(class, reason, stack), mfa}
    exit({reason2, {__MODULE__, :call, [conn, env]}})
  end

  defp format_reason(:exit, reason, _), do: reason
  defp format_reason(:throw, reason, stack), do: {{:nocatch, reason}, stack}
  defp format_reason(:error, reason, stack), do: {reason, stack}

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
