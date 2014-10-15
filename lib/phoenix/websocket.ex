defmodule Phoenix.WebSocket do

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def ws_handle(_text, _req, socket), do: socket

      @doc """
      Handles regular messages sent to the socket process

      Each message is forwarded to the "info" event of the socket's authorized channels
      """
      def ws_info(_data, socket), do: socket

      @doc """
      This is called right before the websocket is about to be closed.
      """
      def ws_terminate(_reason, _req, _socket), do: :ok

      def ws_hibernate(_socket), do: :ok
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
