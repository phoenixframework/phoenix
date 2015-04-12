defmodule Phoenix.Channel.Server do
  use GenServer
  alias Phoenix.PubSub

  # TODO: Document me as the transport API.
  @moduledoc false

  def start_link(socket, auth_payload) do
    GenServer.start_link(__MODULE__, [socket, auth_payload])
  end

  @doc """
  Pushes a new message from client to the channel.
  """
  def handle_in(pid, event, payload, ref) do
    GenServer.cast(pid, {:handle_in, event, payload, ref})
  end

  @doc """
  Notifies the channel the client left.

  This event is async and a message is sent back to the
  transport as soon the leave command is processed (but
  before termination).
  """
  def leave(pid, ref) do
    GenServer.cast(pid, {:leave, ref})
  end

  @doc """
  Notifies the channel the client closed.

  This event is synchronous as we want to guarantee
  proper termination of the channel.
  """
  def close(pid) do
    GenServer.call(pid, :close)
  end

  ## Callbacks

  @doc """
  Initializes the Socket server for `Phoenix.Channel` joins.

  To start the server, return `{:ok, socket}`.
  To ignore the join request, return `:ignore`
  Any other result will exit with `:badarg`

  See `Phoenix.Channel.join/3` documentation.
  """

  # TODO: Modify the socket to not allow pushes
  def init([socket, auth_payload]) do
    case socket.channel.join(socket.topic, auth_payload, socket) do
      {:ok, socket} ->
        PubSub.subscribe(socket.pubsub_server, self, socket.topic, link: true)
        push(socket, "phx_reply", %{ref: socket.ref, status: "ok", response: %{}})
        {:ok, put_in(socket.joined, true)}

      :ignore ->
        push(socket, "phx_reply", %{ref: socket.ref, status: "ignore", response: %{}})
        :ignore

      result ->
        {:stop, {:badarg, result}}
    end
  end

  defp push(socket, event, message) do
    send socket.transport_pid, {:socket_push, %Phoenix.Socket.Message{
      topic: socket.topic,
      event: event,
      payload: message
    }}
  end

  def handle_call(:close, _from, socket) do
    {:stop, {:shutdown, :closed}, :ok, socket}
  end

  def handle_cast({:leave, ref}, socket) do
    handle_result({:stop, {:shutdown, :left}, :ok, put_in(socket.ref, ref)}, :handle_in)
  end

  def handle_cast({:handle_in, event, payload, ref}, socket) do
    event
    |> socket.channel.handle_in(payload, put_in(socket.ref, ref))
    |> handle_result(:handle_in)
  end

  @doc """
  Forwards broadcast through `handle_out/3` callbacks
  """
  def handle_info({:socket_broadcast, msg}, socket) do
    msg.event
    |> socket.channel.handle_out(msg.payload, socket)
    |> handle_result(:handle_out)
  end

  @doc """
  Forwards regular Elixir messages through `handle_info/2` callbacks
  """
  def handle_info(msg, socket) do
    msg
    |> socket.channel.handle_info(socket)
    |> handle_result(:handle_info)
  end

  # TODO: Modify the socket to not allow pushes
  def terminate(reason, socket) do
    socket.channel.terminate(reason, socket)
  end

  defp handle_result({:reply, {status, response}, socket}, :handle_in) do
    push socket, "phx_reply", %{status: to_string(status),
                                ref: socket.ref,
                                response: response}
    {:noreply, socket}
  end
  defp handle_result({:reply, status, socket}, :handle_in) when is_atom(status) do
    push socket, "phx_reply", %{status: to_string(status),
                                ref: socket.ref,
                                response: %{}}
    {:noreply, socket}
  end
  defp handle_result({:reply, status, _socket}, :handle_in) do
    raise """
    Channel replies from `handle_in/3` are expected to return one of:

        {:reply, {status :: atom, response :: map}, Socket.t} |
        {:reply, status :: atom, Socket.t}

    got #{inspect status}
    """
  end
  defp handle_result({:reply, _, _socket}, _) do
    raise """
    Channel replies can only be sent from a `handle_in/3` callback.
    Use `push/3` to send an out-of-band message down the socket
    """
  end
  defp handle_result({:noreply, socket}, _callback_type), do: {:noreply, socket}
  defp handle_result({:stop, reason, {status, response}, socket}, :handle_in) do
    push socket, "phx_reply", %{status: to_string(status),
                                ref: socket.ref,
                                response: response}
    {:stop, reason, socket}
  end
  defp handle_result({:stop, reason, status, socket}, :handle_in) when is_atom(status) do
    push socket, "phx_reply", %{status: to_string(status),
                                ref: socket.ref,
                                response: %{}}
    {:stop, reason, socket}
  end
  defp handle_result({:stop, reason, socket}, _callback_type), do: {:stop, reason, socket}
  defp handle_result(result, :handle_in) do
    raise """
    Expected `handle_in/3` to return one of:

        {:noreply, Socket.t} |
        {:reply, {status :: atom, response :: map}, Socket.t} |
        {:reply, status :: atom, Socket.t} |
        {:stop, reason :: term, Socket.t} |
        {:stop, reason :: term, {status :: atom, response :: map}, Socket.t} |
        {:stop, reason :: term, status :: atom, Socket.t}

    got #{inspect result}
    """
  end
  defp handle_result(result, callback_type) do
    raise """
    Expected `#{callback_type}` to return one of:

        {:noreply, Socket.t} |
        {:stop, reason :: term, Socket.t} |

    got #{inspect result}
    """
  end
end
