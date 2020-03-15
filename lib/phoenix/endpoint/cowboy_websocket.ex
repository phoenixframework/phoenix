defmodule Phoenix.Endpoint.CowboyWebSocket do
  @moduledoc false

  if Code.ensure_loaded?(:cowboy_websocket_handler) do
    @behaviour :cowboy_websocket_handler
  end

  @connection Plug.Adapters.Cowboy.Conn
  @already_sent {:plug_conn, :sent}

  def init({transport, :http}, req, {module, args}) when transport in [:tcp, :ssl] do
    {endpoint, handler, opts} = args
    conn = @connection.conn(req, transport)

    try do
      case module.connect(conn, endpoint, handler, opts) do
        {:ok, %Plug.Conn{adapter: {@connection, req}} = conn, args} ->
          timeout = Keyword.fetch!(opts, :timeout)
          req = copy_resp_headers(conn, req)
          {:upgrade, :protocol, __MODULE__, req, {handler, args, timeout}}

        {:error, %Plug.Conn{adapter: {@connection, req}} = conn} ->
          {:shutdown, copy_resp_headers(conn, req), :no_state}
      end
    catch
      kind, reason ->
        # Although we are not performing a call, we are using the call
        # function for now so it is properly handled in error reports.
        mfa = {module, :call, [conn, args]}
        {:upgrade, :protocol, __MODULE__, req, {:error, mfa, kind, reason, __STACKTRACE__}}
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

  def upgrade(req, env, __MODULE__, {_, _, _} = args) do
    resume(:cowboy_websocket, :upgrade, [req, env, __MODULE__, args])
  end

  def terminate(_reason, _req, _state) do
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

  defp copy_resp_headers(%Plug.Conn{} = conn, req) do
    Enum.reduce(conn.resp_headers, req, fn {key, val}, acc ->
      :cowboy_req.set_resp_header(key, val, acc)
    end)
  end

  ## Websocket callbacks

  def websocket_init(_transport, req, {handler, args, timeout}) do
    {:ok, state} = handler.init(args)
    {:ok, :cowboy_req.compact(req), {handler, state}, timeout}
  end

  def websocket_handle({opcode, payload}, req, {handler, state})
      when opcode in [:text, :binary] do
    handle_reply(req, handler, handler.handle_in({payload, opcode: opcode}, state))
  end

  def websocket_handle(_other, req, state) do
    {:ok, req, state}
  end

  def websocket_info(message, req, {handler, state}) do
    handle_reply(req, handler, handler.handle_info(message, state))
  end

  def websocket_terminate({:error, :closed}, _req, {handler, state}) do
    handler.terminate(:closed, state)
    :ok
  end

  def websocket_terminate({:remote, :closed}, _req, {handler, state}) do
    handler.terminate(:closed, state)
    :ok
  end

  def websocket_terminate({:remote, code, _}, _req, {handler, state})
      when code in 1000..1003 or code in 1005..1011 or code == 1015 do
    handler.terminate(:closed, state)
    :ok
  end

  def websocket_terminate(reason, _req, {handler, state}) do
    handler.terminate(reason, state)
    :ok
  end

  defp handle_reply(req, handler, {:ok, state}),
    do: {:ok, req, {handler, state}}

  defp handle_reply(req, handler, {:push, data, state}),
    do: {:reply, data, req, {handler, state}}

  defp handle_reply(req, handler, {:reply, _status, data, state}),
    do: {:reply, data, req, {handler, state}}

  defp handle_reply(req, handler, {:stop, _reason, state}),
    do: {:shutdown, req, {handler, state}}
end
