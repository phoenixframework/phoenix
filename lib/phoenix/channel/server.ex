defmodule Phoenix.Channel.Server do
  use GenServer
  require Logger
  alias Phoenix.PubSub

  # defmodule InvalidReturnError do
  #   defexception [:message]
  #   def exception(msg) do
  #     %InvalidReturnError{message: "Invalid Handler return: #{inspect msg}"}
  #   end
  # end

  def start_link(socket, auth_payload) do
    GenServer.start_link(__MODULE__, [socket, auth_payload])
  end

  def init([socket, auth_payload]) do
    Process.flag(:trap_exit, true)

    case socket.channel.join(socket.topic, auth_payload, socket) do
      {:ok, socket} ->
        {:ok, socket}
          socket = put_in(socket, [:pid], self)
          Process.link(socket.adapter_pid)
          send(socket.adapter_pid, {:put_socket, socket.topic, self})
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

  def handle_cast({:handle_in, event, payload}, socket) when event != "join" do
    event
    |> socket.channel.handle_in(payload, socket)
    |> handle_result
  end

  # TODO probably can go away
  # def handle_cast({:handle_out, event, payload}, socket) do
  #   event
  #   |> socket.channel.handle_out(payload, socket)
  #   |> handle_result
  # end

  @doc """
  Receives `%Phoenix.Socket.Message{}` and sends encoded message JSON to client.
  """
  def handle_info({:socket_broadcast, msg}, socket) do
    msg.event
    |> socket.channel.handle_out(msg.payload, socket)
    |> handle_result
  end

  def handle_info(msg, socket) do
    msg
    |> socket.channel.handle_info(socket)
    |> handle_result
  end

  def terminate(_reason, :left) do
    :ok
  end
  def terminate(reason, socket) do
    {:stop, :normal, :left} = leave_and_stop(reason, socket)

    :ok
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
    send socket.adapter_pid, {:delete_socket, socket.topic}

    {:stop, :normal, :left}
  end
end
