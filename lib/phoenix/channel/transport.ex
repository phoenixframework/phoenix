defmodule Phoenix.Channel.Transport do
  alias Phoenix.Socket
  alias Phoenix.Channel
  alias Phoenix.Socket.Message

  @moduledoc """
  """

  defmodule InvalidReturn do
    defexception [:message]
    def exception(msg) do
      %InvalidReturn{message: "Invalid Handler return: #{inspect msg}"}
    end
  end


  def dispatch(msg, socket) do
    socket
    |> Socket.set_current_channel(msg.channel, msg.topic)
    |> dispatch(msg.channel, msg.event, msg.message)
  end

  defp dispatch(socket, "phoenix", "heartbeat", _msg) do
    msg = %Message{channel: "phoenix", topic: "conn", event: "heartbeat", message: %{}}
    send socket.pid, msg

    {:ok, socket}
  end
  defp dispatch(socket, channel, "join", msg) do
    socket
    |> socket.router.match(:socket, channel, "join", msg)
    |> handle_result("join")
  end
  defp dispatch(socket, channel, event, msg) do
    if Socket.authenticated?(socket, channel, socket.topic) do
      socket
      |> socket.router.match(:socket, channel, event, msg)
      |> handle_result(event)
    else
      handle_result({:error, socket, :unauthenticated}, event)
    end
  end

  defp handle_result({:ok, socket}, "join") do
    {:ok, Channel.subscribe(socket, socket.channel, socket.topic)}
  end
  defp handle_result(socket = %Socket{}, "leave") do
    {:ok, Channel.unsubscribe(socket, socket.channel, socket.topic)}
  end
  defp handle_result(socket = %Socket{}, _event) do
    {:ok, socket}
  end
  defp handle_result({:error, socket, reason}, _event) do
    {:error, socket, reason}
  end
  defp handle_result(bad_return, event) when event in ["join", "leave"] do
    raise InvalidReturn, message: """
      expected {:ok, %Socket{}} | {:error, %Socket{}, reason} got #{inspect bad_return}
    """
  end
  defp handle_result(bad_return, _event) do
    raise InvalidReturn, message: """
      expected %Socket{} got #{inspect bad_return}
    """
  end

  def dispatch_info(socket = %Socket{},  data) do
    socket = Enum.reduce socket.channels, socket, fn {channel, topic}, socket ->
      {:ok, socket} = dispatch_info(socket, channel, topic, data)
      socket
    end
    {:ok, socket}
  end
  def dispatch_info(socket, channel, topic, data) do
    socket
    |> Socket.set_current_channel(channel, topic)
    |> socket.router.match(:socket, channel, "info", data)
    |> handle_result("info")
  end

  def dispatch_leave(socket, reason) do
    Enum.each socket.channels, fn {channel, topic} ->
      socket
      |> Socket.set_current_channel(channel, topic)
      |> socket.router.match(:socket, channel, "leave", reason: reason)
      |> handle_result("leave")
    end
    :ok
  end
end
