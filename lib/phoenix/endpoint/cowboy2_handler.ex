defmodule Phoenix.Endpoint.Cowboy2Handler do
  @moduledoc false

  if Code.ensure_loaded?(:cowboy_websocket) and
    function_exported?(:cowboy_websocket, :behaviour_info, 1) do
    @behaviour :cowboy_websocket
  end

  @connection Plug.Cowboy.Conn
  @already_sent {:plug_conn, :sent}

  # Note we keep the websocket state as [handler | state]
  # to avoid conflicts with {endpoint, opts}.
  def init(req, {endpoint, opts}) do
    %{path_info: path_info} = conn = @connection.conn(req)

    try do
      case endpoint.__handler__(path_info, opts) do
        {:websocket, handler, opts} ->
          case Phoenix.Transports.WebSocket.connect(conn, endpoint, handler, opts) do
            {:ok, %{adapter: {@connection, req}}, state} ->
              timeout = Keyword.fetch!(opts, :timeout)
              compress = Keyword.fetch!(opts, :compress)
              cowboy_opts = %{idle_timeout: timeout, compress: compress}
              {:cowboy_websocket, req, [handler | state], cowboy_opts}

            {:error, %{adapter: {@connection, req}}} ->
              {:ok, req, {handler, opts}}
          end

        {:plug, handler, opts} ->
          %{adapter: {@connection, req}} =
            conn
            |> handler.call(opts)
            |> maybe_send(handler)

          {:ok, req, {handler, opts}}
      end
    catch
      :error, value ->
        stack = System.stacktrace()
        exception = Exception.normalize(:error, value, stack)
        exit({{exception, stack}, {endpoint, :call, [conn, opts]}})

      :throw, value ->
        stack = System.stacktrace()
        exit({{{:nocatch, value}, stack}, {endpoint, :call, [conn, opts]}})

      :exit, value ->
        exit({value, {endpoint, :call, [conn, opts]}})
    after
      receive do
        @already_sent -> :ok
      after
        0 -> :ok
      end
    end
  end

  defp maybe_send(%Plug.Conn{state: :unset}, _plug), do: raise(Plug.Conn.NotSentError)
  defp maybe_send(%Plug.Conn{state: :set} = conn, _plug), do: Plug.Conn.send_resp(conn)
  defp maybe_send(%Plug.Conn{} = conn, _plug), do: conn

  defp maybe_send(other, plug) do
    raise "Cowboy2 adapter expected #{inspect(plug)} to return Plug.Conn but got: " <>
            inspect(other)
  end

  ## Websocket callbacks

  def websocket_init([handler | state]) do
    {:ok, state} = handler.init(state)
    {:ok, [handler | state]}
  end

  def websocket_handle({opcode, payload}, [handler | state]) when opcode in [:text, :binary] do
    handle_reply(handler, handler.handle_in({payload, opcode: opcode}, state))
  end

  def websocket_handle(_other, handler_state) do
    {:ok, handler_state}
  end

  def websocket_info(message, [handler | state]) do
    handle_reply(handler, handler.handle_info(message, state))
  end

  def terminate(_reason, _req, {_handler, _state}) do
    :ok
  end

  def terminate({:error, :closed}, _req, [handler | state]) do
    handler.terminate(:closed, state)
  end

  def terminate({:remote, :closed}, _req, [handler | state]) do
    handler.terminate(:closed, state)
  end

  def terminate({:remote, code, _}, _req, [handler | state])
      when code in 1000..1003 or code in 1005..1011 or code == 1015 do
    handler.terminate(:closed, state)
  end

  def terminate(:remote, _req, [handler | state]) do
    handler.terminate(:closed, state)
  end

  def terminate(reason, _req, [handler | state]) do
    handler.terminate(reason, state)
  end

  defp handle_reply(handler, {:ok, state}), do: {:ok, [handler | state]}
  defp handle_reply(handler, {:push, data, state}), do: {:reply, data, [handler | state]}
  defp handle_reply(handler, {:reply, _status, data, state}), do: {:reply, data, [handler | state]}
  defp handle_reply(handler, {:stop, _reason, state}), do: {:stop, [handler | state]}
end
