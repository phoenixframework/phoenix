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
    init(@connection.conn(req), endpoint, opts, true)
  end

  defp init(conn, endpoint, opts, retry?) do
    case endpoint.__handler__(conn, opts) do
      {:websocket, conn, handler, opts} ->
        case Phoenix.Transports.WebSocket.connect(conn, endpoint, handler, opts) do
          {:ok, %Plug.Conn{adapter: {@connection, req}} = conn, state} ->
            cowboy_opts =
              opts
              |> Enum.flat_map(fn
                {:timeout, timeout} -> [idle_timeout: timeout]
                {:compress, _} = opt -> [opt]
                {:max_frame_size, _} = opt -> [opt]
                _other -> []
              end)
              |> Map.new()

            {:cowboy_websocket, copy_resp_headers(conn, req), [handler | state], cowboy_opts}

          {:error, %Plug.Conn{adapter: {@connection, req}} = conn} ->
            {:ok, copy_resp_headers(conn, req), {handler, opts}}
        end

      {:plug, conn, handler, opts} ->
        %{adapter: {@connection, req}} =
          conn
          |> handler.call(opts)
          |> maybe_send(handler)

        {:ok, req, {handler, opts}}
    end
  catch
    kind, reason ->
      case System.stacktrace() do
        # Maybe the handler is not available because the code is being recompiled.
        # Sync with the code reloader and retry once.
        [{^endpoint, :__handler__, _, _} | _] when reason == :undef and retry? ->
          Phoenix.CodeReloader.Server.sync()
          init(conn, endpoint, opts, false)

        stacktrace ->
          exit_on_error(kind, reason, stacktrace, {endpoint, :call, [conn, opts]})
      end
  after
    receive do
      @already_sent -> :ok
    after
      0 -> :ok
    end
  end

  defp maybe_send(%Plug.Conn{state: :unset}, _plug), do: raise(Plug.Conn.NotSentError)
  defp maybe_send(%Plug.Conn{state: :set} = conn, _plug), do: Plug.Conn.send_resp(conn)
  defp maybe_send(%Plug.Conn{} = conn, _plug), do: conn

  defp maybe_send(other, plug) do
    raise "Cowboy2 adapter expected #{inspect(plug)} to return Plug.Conn but got: " <>
            inspect(other)
  end

  defp exit_on_error(
         :error,
         %Plug.Conn.WrapperError{kind: kind, reason: reason, stack: stack},
         _stack,
         call
       ) do
    exit_on_error(kind, reason, stack, call)
  end

  defp exit_on_error(:error, value, stack, call) do
    exception = Exception.normalize(:error, value, stack)
    exit({{exception, stack}, call})
  end

  defp exit_on_error(:throw, value, stack, call) do
    exit({{{:nocatch, value}, stack}, call})
  end

  defp exit_on_error(:exit, value, _stack, call) do
    exit({value, call})
  end

  defp copy_resp_headers(%Plug.Conn{} = conn, req) do
    Enum.reduce(conn.resp_headers, req, fn {key, val}, acc ->
      :cowboy_req.set_resp_header(key, val, acc)
    end)
  end

  defp handle_reply(handler, {:ok, state}), do: {:ok, [handler | state]}
  defp handle_reply(handler, {:push, data, state}), do: {:reply, data, [handler | state]}

  defp handle_reply(handler, {:reply, _status, data, state}),
    do: {:reply, data, [handler | state]}

  defp handle_reply(handler, {:stop, _reason, state}), do: {:stop, [handler | state]}

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
end
