defmodule Phoenix.Channel.ControlChannel do
  use Phoenix.Channel

  @moduledoc """
  Phoenix's control channel for framework specific messages
  """

  def join("phoenix", _msg, socket) do
    {:ok, socket}
  end

  def handle_out("assets:change", _message, socket) do
    reply socket, "assets:change", %{}
    {:ok, socket}
  end
end
