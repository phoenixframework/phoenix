defmodule Phoenix.Debugger.DebugSocket do
  use Phoenix.Socket

  channel "phoenix:debugger", Phoenix.Debugger.WebConsoleChannel

  def connect(_params, socket, _connect_info) do
    if socket.endpoint.config(:web_debugger) do
      {:ok, socket}
    else
      :error
    end
  end

  def id(_socket), do: nil
end
