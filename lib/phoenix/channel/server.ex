defmodule Phoenix.Channel.Server do
  use GenServer

  alias Phoenix.PubSub
  alias Phoenix.Socket
  alias Phoenix.Socket.Broadcast
  alias Phoenix.Socket.Reply

  # TODO: Document me as the transport API.
  @moduledoc false

  @doc """
  Joins the channel in socket with authentication payload.
  """
  @spec join(Phoenix.Socket.t, map) :: {:ok, map, pid} | {:error, map}
  def join(socket, auth_payload) do
    ref = make_ref()

    case GenServer.start_link(__MODULE__, {socket, auth_payload, self(), ref}) do
      {:ok, pid} ->
        receive do: ({^ref, reply} -> {:ok, reply, pid})
      :ignore ->
        receive do: ({^ref, reply} -> {:error, reply})
      {:error, _} ->
        {:error, %{reason: "join crashed"}}
    end
  end

  @doc """
  Pushes a message from client to the channel.
  """
  def push(pid, event, ref, payload) do
    GenServer.cast(pid, {:push, event, ref, payload})
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

  @doc false
  def init({socket, auth_payload, parent, ref}) do
    case socket.channel.join(socket.topic, auth_payload, socket) do
      {:ok, socket} ->
        join(socket, %{}, parent, ref)
      {:ok, reply, socket} ->
        join(socket, reply, parent, ref)
      {:error, reply} ->
        send(parent, {ref, reply})
        :ignore
      other ->
        raise """
        Channel join is expected to return one of:

            {:ok, Socket.t} |
            {:ok, reply :: map, Socket.t} |
            {:error, reply :: map, Socket.t}

        got #{inspect other}
        """
    end
  end

  defp join(socket, reply, parent, ref) do
    PubSub.subscribe(socket.pubsub_server, self(), socket.topic, link: true)
    send(parent, {ref, reply})
    {:ok, put_in(socket.joined, true)}
  end

  @doc false
  def handle_cast({:leave, ref}, socket) do
    handle_result({:stop, {:shutdown, :left}, :ok, put_in(socket.ref, ref)}, :handle_in)
  end

  def handle_cast({:push, event, ref, payload}, socket) do
    event
    |> socket.channel.handle_in(payload, put_in(socket.ref, ref))
    |> handle_result(:handle_in)
  end

  @doc false
  def handle_info(%Broadcast{} = msg, socket) do
    msg.event
    |> socket.channel.handle_out(msg.payload, socket)
    |> handle_result(:handle_out)
  end

  def handle_info(msg, socket) do
    msg
    |> socket.channel.handle_info(socket)
    |> handle_result(:handle_info)
  end

  @doc false
  def terminate(reason, socket) do
    socket.channel.terminate(reason, socket)
  end

  ## Handle results

  defp handle_result({:reply, reply, %Socket{} = socket}, callback) do
    handle_reply(socket, reply, callback)
    {:noreply, socket}
  end

  defp handle_result({:stop, reason, reply, socket}, callback) do
    handle_reply(socket, reply, callback)
    {:stop, reason, socket}
  end

  defp handle_result({:stop, reason, socket}, _callback) do
    {:stop, reason, socket}
  end

  defp handle_result({:noreply, socket}, _callback) do
    {:noreply, socket}
  end

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

  defp handle_result(result, callback) do
    raise """
    Expected `#{callback}` to return one of:

        {:noreply, Socket.t} |
        {:stop, reason :: term, Socket.t} |

    got #{inspect result}
    """
  end

  ## Handle replies

  defp handle_reply(socket, {status, payload}, :handle_in)
       when is_atom(status) and is_map(payload) do
    send socket.transport_pid, %Reply{status: status, topic: socket.topic,
                                      ref: socket.ref, payload: payload}
  end

  defp handle_reply(socket, status, :handle_in) when is_atom(status) do
    handle_reply(socket, {status, %{}}, :handle_in)
  end

  defp handle_reply(_socket, reply, :handle_in) do
    raise """
    Channel replies from `handle_in/3` are expected to be one of:

        status :: atom
        {status :: atom, response :: map}

    for example:

        {:reply, :ok, socket}
        {:reply, {:ok, %{}}, socket}
        {:stop, :shutdown, {:error, %{}}, socket}

    got #{inspect reply}
    """
  end

  defp handle_reply(_socket, _reply, _other) do
    raise """
    Channel replies can only be sent from a `handle_in/3` callback.
    Use `push/3` to send an out-of-band message down the socket
    """
  end
end
