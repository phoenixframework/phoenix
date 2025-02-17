# A tiny proxy that stores all output sent to the group leader
# while forwarding all requests to it.
defmodule Phoenix.CodeReloader.Proxy do
  @moduledoc false
  use GenServer

  def start() do
    GenServer.start(__MODULE__, :ok)
  end

  def diagnostics(proxy, diagnostics) do
    GenServer.cast(proxy, {:diagnostics, diagnostics})
  end

  def stop(proxy) do
    GenServer.call(proxy, :stop, :infinity)
  end

  ## Callbacks

  def init(:ok) do
    {:ok, []}
  end

  def handle_cast({:diagnostics, diagnostics}, output) do
    {:noreply, diagnostics |> Enum.map(&diagnostic_to_chars/1) |> Enum.reverse(output)}
  end

  def handle_call(:stop, _from, output) do
    {:stop, :normal, Enum.reverse(output), output}
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
        send(Process.group_leader(), msg)
        {:noreply, output}

      _ ->
        {:noreply, output}
    end
  end

  defp put_chars(from, reply, chars, output) do
    send(Process.group_leader(), {:io_request, from, reply, {:put_chars, chars}})
    {:noreply, [chars | output]}
  end

  defp diagnostic_to_chars(%{severity: :error, message: "**" <> _ = message}) do
    "\n#{message}\n"
  end

  defp diagnostic_to_chars(%{severity: severity, message: message, file: file, position: position}) when is_binary(file) do
    "\n#{severity}: #{message}\n  #{Path.relative_to_cwd(file)}#{position(position)}\n"
  end

  defp diagnostic_to_chars(%{severity: severity, message: message}) do
    "\n#{severity}: #{message}\n"
  end

  defp position({line, col}), do: ":#{line}:#{col}"
  defp position(line) when is_integer(line) and line > 0, do: ":#{line}"
  defp position(_), do: ""
end
