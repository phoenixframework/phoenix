defmodule Phoenix.Channel.Server do
  use GenServer
  require Logger
  alias Phoenix.PubSub

  @moduledoc """
  Handles `%Phoenix.Socket{}` state and invokes channel callbacks.

  ## handle_info/2
  Regular Elixir messages are forwarded to the socket channel's
  `handle_info/2` callback.

  """

  def start_link(socket, auth_payload) do
    GenServer.start_link(__MODULE__, [socket, auth_payload])
  end

  def init([socket, auth_payload]) do
    case socket.channel.join(socket.topic, auth_payload, socket) do
      {:ok, socket} ->
        {:ok, socket}
          socket = put_in(socket, [:pid], self)
          PubSub.subscribe(socket.pubsub_server, socket.pid, socket.topic, link: true)

          {:ok, socket}

      :ignore -> :ignore

      result ->
        Logger.error fn -> """
            Expected `#{inspect socket.channel}.join/3` to return `{:ok, socket} | :ignore}`,
            got #{inspect result}
          """
        end
        {:stop, {:badarg, result}}
    end
  end

  def handle_cast({:handle_in, "leave", payload}, socket) do
    leave_and_stop(payload, socket)
  end

  @doc """
  Forwards incoming client messages through `handle_in/3` callbacks
  """
  def handle_cast({:handle_in, event, payload}, socket) when event != "join" do
    event
    |> socket.channel.handle_in(payload, socket)
    |> handle_result
  end

  @doc """
  Forwards broadcast through `handle_out/3` callbacks
  """
  def handle_info({:socket_broadcast, msg}, socket) do
    msg.event
    |> socket.channel.handle_out(msg.payload, socket)
    |> handle_result
  end

  @doc """
  Forwards regular Elixir messages through `handle_info/2` callbacks
  """
  def handle_info(msg, socket) do
    msg
    |> socket.channel.handle_info(socket)
    |> handle_result
  end


  defp handle_result({:ok, socket}), do: {:noreply, socket}
  defp handle_result({:leave, socket}), do: leave_and_stop(:normal, socket)
  defp handle_result({:error, reason, socket}) do
    {:stop, {:error, reason}, socket}
  end
  defp handle_result(result) do
    raise """
      Expected callback to return `{:ok, socket} | {:error, reason, socket} || {:leave, socket}`,
      got #{inspect result}
    """
  end

  defp leave_and_stop(reason, socket) do
    {:ok, socket} = socket.channel.leave(reason, socket)

    PubSub.unsubscribe(socket.pubsub_server, socket.pid, socket.topic)

    {:stop, :normal, :left}
  end
end
