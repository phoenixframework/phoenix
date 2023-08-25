defmodule Phoenix.Debugger.WebConsoleChannel do
  use Phoenix.Channel

  alias Phoenix.Debugger.WebConsoleLogger

  def join(_topic, _params, socket) do
    WebConsoleLogger.subscribe(socket.endpoint)

    editor =
      case System.fetch_env("ELIXIR_EDITOR") do
        {:ok, cmd} ->
          cmd

        :error ->
          IO.warn("""
          no ELIXIR_EDITOR environment variable configured for jumping to source files.

              export ELIXIR_EDITOR="code -r -g __FILE__:__LINE__"
          """)

          nil
      end

    {:ok, assign(socket, editor: editor)}
  end

  def handle_in("open", %{"file" => file, "line" => line}, socket) do
    open(socket.assigns.editor, file, line)
    {:noreply, socket}
  end

  defp open(nil, _file, _line), do: :noop

  defp open(editor, file, line) do
    [cmd | args] =
      editor
      |> String.replace("__FILE__", file)
      |> String.replace("__LINE__", line)
      |> String.split(" ")

    System.cmd(cmd, args)
  end

  def handle_info({WebConsoleLogger, level, msg, _ts, meta}, socket) do
    push(socket, "log", %{
      level: to_string(level),
      msg: IO.iodata_to_binary(msg),
      file: meta[:file],
      line: meta[:line]
    })

    {:noreply, socket}
  end
end
