# A tiny proxy that stores all output sent to the group leader
# while forwarding all requests to it.
defmodule Phoenix.CodeReloader.Proxy do
  @moduledoc false
  use GenServer

  def start() do
    GenServer.start(__MODULE__, :ok)
  end

  def stop(proxy) do
    GenServer.call(proxy, :stop)
  end

  ## Callbacks

  def init(:ok) do
    {:ok, ""}
  end

  def handle_call(:stop, _from, output) do
    {:stop, :normal, output, output}
  end

  def handle_info(msg, output) do
    case msg do
      {:io_request, from, reply, {:put_chars, chars}} ->
        put_chars(from, reply, chars, output)

      {:io_request, from, reply, {:put_chars, m, f, as}} ->
        put_chars(from, reply, apply(m, f, as), output)

      {:io_request, from, reply, {:put_chars, _encoding, chars}} ->
        put_chars(from, reply, chars, output)

      {:io_request, from, reply, {:put_chars, _encoding, m, f, as}} ->
        put_chars(from, reply, apply(m, f, as), output)

      {:io_request, _from, _reply, _request} = msg ->
        send(Process.group_leader, msg)
        {:noreply, output}

      _ ->
        {:noreply, output}
    end
  end

  defp put_chars(from, reply, chars, output) do
    send(Process.group_leader, {:io_request, from, reply, {:put_chars, chars}})
    {:noreply, output <> IO.chardata_to_string(chars)}
  end
end
