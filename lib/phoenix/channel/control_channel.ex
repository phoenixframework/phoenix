defmodule Phoenix.Channel.ControlChannel do
  use Phoenix.Channel

  @moduledoc """
  Phoenix's control channel for framework specific messages
  """

  def join("phoenix", _msg, socket) do
    :ok = Application.ensure_started(:fs)
    patterns = socket.endpoint.config(:live_reload)[:patterns]
    :fs.subscribe()

    {:ok, assign(socket, :patterns, patterns)}
  end

  def handle_info({_pid, {:fs, :file_event}, {path, _event}}, socket) do
    if matches_any_pattern?(path, socket.assigns[:patterns]) do
      push socket, "assets:change", %{}
    end

    {:ok, socket}
  end


  defp matches_any_pattern?(path, patterns) do
    Enum.any?(patterns, fn pattern -> String.match?(to_string(path), pattern) end)
  end
end
