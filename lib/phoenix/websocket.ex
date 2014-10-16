defmodule Phoenix.WebSocket do

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      def ws_handle(_text, state), do: state

      @doc """
      Handles regular messages sent to the socket process

      Each message is forwarded to the "info" event of the socket's authorized channels
      """
      def ws_info(_data, state), do: state

      @doc """
      This is called right before the websocket is about to be closed.
      """
      def ws_terminate(_reason, _state), do: :ok

      def ws_hibernate(_state), do: :ok

      defoverridable ws_handle: 2, ws_info: 2, ws_terminate: 2, ws_hibernate: 1
    end
  end

  def reply(pid, msg) do
    send(pid, {:reply, msg})
  end

  def terminate(pid) do
    send(pid, :shutdown)
  end

  def hibernate(pid) do
    send(pid, :hibernate)
  end
end
