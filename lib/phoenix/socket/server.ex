defmodule Phoenix.Socket.Supervisor do
  @moduledoc false
  use Supervisor
  alias Phoenix.Socket

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_child(%Socket{} = socket, channel, topic, message) do
    Supervisor.start_child(__MODULE__, [socket, channel, topic, message])
  end

  def terminate_child(child) do
    Supervisor.terminate_child(__MODULE__, child)
  end

  def init(:ok) do
    children = [
      worker(Phoenix.Socket.Server, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end


defmodule Phoenix.Socket.Server do
  @moduledoc """
  Defines a server for socket operations. Delegates to the actual Transport.
  """
  use GenServer
  alias Phoenix.Socket
  alias Phoenix.PubSub

  # External API

  def start_link(%Socket{} = socket, channel, topic, message) do
    GenServer.start_link(__MODULE__, {socket, channel, topic, message})
  end

  def dispatch_in(server, topic, event, message) do
    GenServer.call(server, {:dispatch_in, topic, event, message})
  end

  def dispatch_out(server, event, message) do
    GenServer.call(server, {:dispatch_out, event, message})
  end

  def dispatch_leave(server, message) do
    GenServer.call(server, {:dispatch_leave, :ignore_topic, message})
  end
  def dispatch_leave(server, topic, message) do
    GenServer.call(server, {:dispatch_leave, topic, message})
  end

  def authorized?(server, topic) do
    GenServer.call(server, {:authorized, topic})
  end

  # Server internal

  def init({%Socket{} = socket, channel, topic, message}) do
    Process.flag(:trap_exit, true)
    topic
    |> channel.join(message, Socket.put_channel(socket, channel))
    |> handle_init
  end

  def handle_call({:dispatch_in, topic, event, message}, _from, socket) do
    if Socket.authorized?(socket, topic) do
      socket.channel.handle_in(event, message, socket)
      |> create_reply
    else
      create_reply({:error, :unauthenticated, socket})
    end
  end

  def handle_call({:dispatch_out, event, message}, _from, socket) do
    socket.channel.handle_out(event, message, socket)
    |> create_reply
  end

  def handle_call({:dispatch_leave, :ignore_topic, message}, _from, socket) do
    socket.channel.leave(message, socket)
    |> handle_stop
  end

  def handle_call({:dispatch_leave, topic, message}, _from, socket) do
    if Socket.authorized?(socket, topic) do
      socket.channel.leave(message, socket)
      |> handle_stop
    else
      handle_stop({:error, :unauthenticated, socket})
    end
  end

  def handle_call({:authorized, topic}, _from, socket) do
    {:reply, Socket.authorized?(socket, topic), socket}
  end

  def handle_info(message, socket) do
    {:ok, socket} = socket.channel.handle_info(message, socket)
    # TODO accept the normal channel results here?
    {:noreply, socket}
  end

  def terminate(:bad_return, socket), do: :ok
  def terminate(_reason, socket) do
    PubSub.unsubscribe(socket.pubsub_server, socket.pid, socket.topic)
    :ok
  end

  # Internal

  defp handle_init({:ok, %Socket{} = socket}) do
    PubSub.subscribe(socket.pubsub_server, socket.pid, socket.topic, link: true)
    {:ok, Socket.authorize(socket, socket.topic)}
  end
  defp handle_init(:ignore),                          do: :ignore
  defp handle_init({:error, reason, %Socket{} = s}),  do: {:stop, {reason, s}}
  defp handle_init(bad_return),                       do: {:stop, {{:invalid_return, bad_return}, :undefined}}

  defp create_reply({result, %Socket{} = s}),         do: {:reply, {result, self}, s}
  defp create_reply({:error, reason, %Socket{} = s}), do: {:reply, {:error, {reason, self}}, s}
  defp create_reply(bad_return),                      do: {:reply, {:error, {{:invalid_return, bad_return}}, self}, %{}}

  defp handle_stop({result, %Socket{} = s}) do
    {:stop, :normal, {result, self}, Socket.deauthorize(s)}
  end
  defp handle_stop({:error, reason, %Socket{} = s}) do
    {:stop, reason, {:error, {reason, self}}, Socket.deauthorize(s)}
  end
  defp handle_stop(bad_return) do
    {:stop, :bad_return, {:error, {{:invalid_return, bad_return}}, self}, %{}}
  end
end
