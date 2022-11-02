defmodule Phoenix.Endpoint.Cowboy2Handler do
  @moduledoc false

  @behaviour :cowboy_websocket

  # We never actually call this; it's just here to quell compiler warnings
  @impl true
  def init(req, state), do: {:cowboy_websocket, req, state}

  defp handle_reply(handler, {:ok, state}), do: {:ok, [handler | state]}
  defp handle_reply(handler, {:push, data, state}), do: {:reply, data, [handler | state]}

  defp handle_reply(handler, {:reply, _status, data, state}),
    do: {:reply, data, [handler | state]}

  defp handle_reply(handler, {:stop, _reason, state}), do: {:stop, [handler | state]}

  defp handle_control_frame(payload_with_opts, handler_state) do
    [handler | state] = handler_state
    reply =
      if function_exported?(handler, :handle_control, 2) do
        handler.handle_control(payload_with_opts, state)
      else
        {:ok, state}
      end

    handle_reply(handler, reply)
  end

  @impl true
  def websocket_init({handler, process_flags, state}) do
    for {key, value} <- process_flags do
      :erlang.process_flag(key, value)
    end

    {:ok, state} = handler.init(state)
    {:ok, [handler | state]}
  end

  @impl true
  def websocket_handle({opcode, payload}, [handler | state]) when opcode in [:text, :binary] do
    handle_reply(handler, handler.handle_in({payload, opcode: opcode}, state))
  end

  def websocket_handle({opcode, payload}, handler_state) when opcode in [:ping, :pong] do
    handle_control_frame({payload, opcode: opcode}, handler_state)
  end

  def websocket_handle(opcode, handler_state) when opcode in [:ping, :pong] do
    handle_control_frame({nil, opcode: opcode}, handler_state)
  end

  def websocket_handle(_other, handler_state) do
    {:ok, handler_state}
  end

  @impl true
  def websocket_info(message, [handler | state]) do
    handle_reply(handler, handler.handle_info(message, state))
  end

  @impl true
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
