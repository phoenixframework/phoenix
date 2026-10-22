defmodule Phoenix.Channel.Server do
  @moduledoc false
  use GenServer, restart: :temporary

  @behaviour Phoenix.PubSub.Sender

  require Logger

  alias Phoenix.PubSub
  alias Phoenix.Socket
  alias Phoenix.Socket.{Broadcast, Message, Reply, PoolSupervisor}

  ## Socket API

  @doc """
  Joins the channel in socket with authentication payload.
  """
  @spec join(Socket.t(), module, Message.t(), keyword) :: {:ok, term, pid} | {:error, term}
  def join(socket, channel, message, opts) do
    %{topic: topic, payload: payload, ref: ref, join_ref: join_ref} = message

    starter = opts[:starter] || (&PoolSupervisor.start_child/3)
    assigns = Map.merge(socket.assigns, Keyword.get(opts, :assigns, %{}))

    socket = %{
      socket
      | topic: topic,
        channel: channel,
        join_ref: join_ref || ref,
        assigns: assigns
    }

    ref = make_ref()
    from = {self(), ref}
    child_spec = channel.child_spec({socket.endpoint, from})

    case starter.(socket, from, child_spec) do
      {:ok, pid} ->
        send(pid, {Phoenix.Channel, payload, from, socket})
        mon_ref = Process.monitor(pid)

        receive do
          {^ref, {:ok, reply}} ->
            Process.demonitor(mon_ref, [:flush])
            {:ok, reply, pid}

          {^ref, {:error, reply}} ->
            Process.demonitor(mon_ref, [:flush])
            {:error, reply}

          {:DOWN, ^mon_ref, _, _, reason} ->
            Logger.error(fn -> Exception.format_exit(reason) end)
            {:error, %{reason: "join crashed"}}
        end

      {:error, reason} ->
        Logger.error(fn -> Exception.format_exit(reason) end)
        {:error, %{reason: "join crashed"}}
    end
  end

  @doc """
  Gets the socket from the channel.

  Used by channel tests.
  """
  @spec socket(pid) :: Socket.t()
  def socket(pid) do
    GenServer.call(pid, :socket)
  end

  @doc """
  Emulates the socket being closed.

  Used by channel tests.
  """
  @spec close(pid, timeout) :: :ok
  def close(pid, timeout) do
    GenServer.cast(pid, :close)
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    after
      timeout ->
        Process.exit(pid, :kill)
        receive do: ({:DOWN, ^ref, _, _, _} -> :ok)
    end
  end

  ## Channel API

  @doc """
  Hook invoked by Phoenix.PubSub to deliver a message to a channel subscription.

  Broadcasts not intercepted by the channel are encoded once per
  serializer and sent directly to the transport process.
  """
  def send(pid, {transport_pid, serializer, intercepts}, %Broadcast{event: event} = msg, cache) do
    if event in intercepts do
      send(pid, msg)
      cache
    else
      case cache do
        %{^serializer => encoded_msg} ->
          send(transport_pid, encoded_msg)
          cache

        _ ->
          encoded_msg = serializer.fastlane!(msg)
          send(transport_pid, encoded_msg)
          Map.put(cache || %{}, serializer, encoded_msg)
      end
    end
  end

  def send(pid, _meta, msg, cache) do
    send(pid, msg)
    cache
  end

  # TODO: Remove in Phoenix 1.10
  #
  # Nodes running Phoenix 1.8 broadcast with this module as dispatcher,
  # so it is still invoked for broadcasts coming from those nodes.
  # Subscriptions carry their own sender, so we delegate to the default
  # dispatching.
  @doc false
  def dispatch(entries, from, message) do
    PubSub.dispatch(entries, from, message)
  end

  @doc """
  Broadcasts on the given pubsub server with the given
  `topic`, `event` and `payload`.

  The message is encoded as `Phoenix.Socket.Broadcast`.
  """
  def broadcast(pubsub_server, topic, event, payload)
      when is_binary(topic) and is_binary(event) do
    broadcast = %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }

    PubSub.broadcast(pubsub_server, topic, broadcast)
  end

  @doc """
  Broadcasts on the given pubsub server with the given
  `topic`, `event` and `payload`.

  Raises in case of crashes.
  """
  def broadcast!(pubsub_server, topic, event, payload)
      when is_binary(topic) and is_binary(event) do
    broadcast = %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }

    PubSub.broadcast!(pubsub_server, topic, broadcast)
  end

  @doc """
  Broadcasts on the given pubsub server with the given
  `from`, `topic`, `event` and `payload`.

  The message is encoded as `Phoenix.Socket.Broadcast`.
  """
  def broadcast_from(pubsub_server, from, topic, event, payload)
      when is_binary(topic) and is_binary(event) do
    broadcast = %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }

    PubSub.broadcast_from(pubsub_server, from, topic, broadcast)
  end

  @doc """
  Broadcasts on the given pubsub server with the given
  `from`, `topic`, `event` and `payload`.

  Raises in case of crashes.
  """
  def broadcast_from!(pubsub_server, from, topic, event, payload)
      when is_binary(topic) and is_binary(event) do
    broadcast = %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }

    PubSub.broadcast_from!(pubsub_server, from, topic, broadcast)
  end

  @doc """
  Broadcasts on the given pubsub server with the given
  `topic`, `event` and `payload`.

  The message is encoded as `Phoenix.Socket.Broadcast`.
  """
  def local_broadcast(pubsub_server, topic, event, payload)
      when is_binary(topic) and is_binary(event) do
    broadcast = %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }

    PubSub.local_broadcast(pubsub_server, topic, broadcast)
  end

  @doc """
  Broadcasts on the given pubsub server with the given
  `from`, `topic`, `event` and `payload`.

  The message is encoded as `Phoenix.Socket.Broadcast`.
  """
  def local_broadcast_from(pubsub_server, from, topic, event, payload)
      when is_binary(topic) and is_binary(event) do
    broadcast = %Broadcast{
      topic: topic,
      event: event,
      payload: payload
    }

    PubSub.local_broadcast_from(pubsub_server, from, topic, broadcast)
  end

  @doc """
  Pushes a message with the given topic, event and payload
  to the given process.

  Payloads are serialized before sending with the configured serializer.
  """
  def push(pid, join_ref, topic, event, payload, serializer)
      when is_binary(topic) and is_binary(event) do
    message = %Message{join_ref: join_ref, topic: topic, event: event, payload: payload}
    send(pid, serializer.encode!(message))
    :ok
  end

  @doc """
  Replies to a given ref to the transport process.

  Payloads are serialized before sending with the configured serializer.
  """
  def reply(pid, join_ref, ref, topic, {status, payload}, serializer)
      when is_binary(topic) do
    reply = %Reply{topic: topic, join_ref: join_ref, ref: ref, status: status, payload: payload}
    send(pid, serializer.encode!(reply))
    :ok
  end

  ## Callbacks

  @doc false
  def init({_endpoint, {pid, _}}) do
    {:ok, Process.monitor(pid)}
  end

  @doc false
  def handle_call(:socket, _from, socket) do
    {:reply, socket, socket}
  end

  @doc false
  def handle_call(msg, from, socket) do
    msg
    |> socket.channel.handle_call(from, socket)
    |> handle_result(:handle_call)
  end

  @doc false
  def handle_cast(:close, socket) do
    {:stop, {:shutdown, :closed}, socket}
  end

  @doc false
  def handle_cast(msg, socket) do
    msg
    |> socket.channel.handle_cast(socket)
    |> handle_result(:handle_cast)
  end

  @doc false
  def handle_info({Phoenix.Channel, auth_payload, {pid, _} = from, socket}, ref) do
    Process.demonitor(ref)
    %{channel: channel, topic: topic, private: private} = socket
    Process.put(:"$initial_call", {channel, :join, 3})
    Process.put(:"$callers", [pid])

    # TODO: replace with Process.put_label/2 when we require Elixir 1.17
    Process.put(:"$process_label", {Phoenix.Channel, channel, topic})

    socket = %{
      socket
      | channel_pid: self(),
        private: Map.merge(channel.__socket__(:private), private)
    }

    start = System.monotonic_time()
    {reply, state} = channel_join(channel, topic, auth_payload, socket)
    duration = System.monotonic_time() - start
    metadata = %{params: auth_payload, socket: socket, result: elem(reply, 0)}
    :telemetry.execute([:phoenix, :channel_joined], %{duration: duration}, metadata)
    GenServer.reply(from, reply)

    with {:noreply, %Socket{} = socket} <- state,
         true <- resumable?(socket) do
      send(socket.transport_pid, {:socket_resumable, self()})
    end

    state
  end

  def handle_info(%Message{topic: topic, ref: ref} = msg, %{topic: topic} = socket) do
    case accept_ref(socket, ref) do
      {:ok, socket} -> handle_message(msg, socket)
      :duplicate -> {:noreply, socket}
    end
  end

  # See Phoenix.Socket.ResumeSession
  def handle_info({:socket_handover, session, serializer}, socket) do
    Process.demonitor(Process.get(:"$phx_transport_ref"), [:flush])
    send(socket.transport_pid, {:socket_handed_over, self()})
    Process.put(:"$phx_transport_ref", Process.monitor(session))
    # a released channel keeps dropping the messages it has seen
    Process.put(:"$phx_last_ref", Process.get(:"$phx_last_ref") || 0)
    {:noreply, %{socket | transport_pid: session, serializer: serializer}}
  end

  def handle_info(
        %Broadcast{event: "phx_drain"},
        %{transport_pid: transport_pid} = socket
      ) do
    send(transport_pid, :socket_drain)
    {:stop, {:shutdown, :draining}, socket}
  end

  def handle_info(
        %Broadcast{topic: topic, event: event, payload: payload},
        %Socket{topic: topic} = socket
      ) do
    # resumable channels don't fastlane, as their transport changes
    if resumable?(socket) and event not in socket.channel.__intercepts__() do
      %{transport_pid: transport_pid, join_ref: join_ref, serializer: serializer} = socket
      push(transport_pid, join_ref, topic, event, payload, serializer)
      {:noreply, socket}
    else
      event
      |> socket.channel.handle_out(payload, socket)
      |> handle_result(:handle_out)
    end
  end

  def handle_info({:DOWN, ref, _, _, reason}, ref) do
    {:stop, reason, ref}
  end

  def handle_info({:DOWN, _, _, transport_pid, reason}, %{transport_pid: transport_pid} = socket) do
    reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
    {:stop, reason, socket}
  end

  def handle_info(msg, %{channel: channel} = socket) do
    if function_exported?(channel, :handle_info, 2) do
      msg
      |> socket.channel.handle_info(socket)
      |> handle_result(:handle_info)
    else
      warn_unexpected_msg(:handle_info, 2, msg, channel)
      {:noreply, socket}
    end
  end

  defp handle_message(%Message{event: "phx_leave", ref: ref}, socket) do
    handle_in({:stop, {:shutdown, :left}, :ok, put_in(socket.ref, ref)})
  end

  defp handle_message(%Message{event: event, payload: payload, ref: ref}, socket) do
    start = System.monotonic_time()
    result = socket.channel.handle_in(event, payload, put_in(socket.ref, ref))
    duration = System.monotonic_time() - start
    metadata = %{ref: ref, event: event, params: payload, socket: socket}
    :telemetry.execute([:phoenix, :channel_handled_in], %{duration: duration}, metadata)
    handle_in(result)
  end

  # Once resumable, the client resends messages it has not received a reply for after
  # resuming. Refs only grow on the client, so we drop the ones we've seen already.
  defp accept_ref(socket, ref) do
    with last when is_integer(last) <- Process.get(:"$phx_last_ref"),
         true <- is_binary(ref),
         {ref, ""} <- Integer.parse(ref) do
      if ref <= last do
        :duplicate
      else
        Process.put(:"$phx_last_ref", ref)
        {:ok, socket}
      end
    else
      _ -> {:ok, socket}
    end
  end

  defp resumable?(%Socket{private: private}) do
    Map.get(private, :phoenix_resume, false) and Map.get(private, :phoenix_resumable, false)
  end

  @doc false
  def code_change(old, %{channel: channel} = socket, extra) do
    if function_exported?(channel, :code_change, 3) do
      channel.code_change(old, socket, extra)
    else
      {:ok, socket}
    end
  end

  @doc false
  def terminate(reason, %{channel: channel} = socket) do
    if function_exported?(channel, :terminate, 2) do
      channel.terminate(reason, socket)
    else
      :ok
    end
  end

  def terminate(_reason, _socket) do
    :ok
  end

  ## Joins

  defp channel_join(channel, topic, auth_payload, socket) do
    case channel.join(topic, auth_payload, socket) do
      {:ok, socket} ->
        {{:ok, %{}}, init_join(socket, channel, topic)}

      {:ok, reply, socket} ->
        {{:ok, reply}, init_join(socket, channel, topic)}

      {:error, reply} ->
        {{:error, reply}, {:stop, :shutdown, socket}}

      other ->
        raise """
        channel #{inspect(socket.channel)}.join/3 is expected to return one of:

            {:ok, Socket.t} |
            {:ok, reply :: map, Socket.t} |
            {:error, reply :: map}

        got #{inspect(other)}
        """
    end
  end

  defp init_join(socket, channel, topic) do
    %{transport_pid: transport_pid, serializer: serializer, pubsub_server: pubsub_server} = socket

    unless pubsub_server do
      raise """
      The :pubsub_server was not configured for endpoint #{inspect(socket.endpoint)}.
      Make sure to start a PubSub process in your application supervision tree:

          {Phoenix.PubSub, [name: YOURAPP.PubSub, adapter: Phoenix.PubSub.PG2]}

      And then add it to your endpoint config:

          config :YOURAPP, YOURAPPWeb.Endpoint,
            # ...
            pubsub_server: YOURAPP.PubSub
      """
    end

    transport_ref = Process.monitor(transport_pid)

    if resumable?(socket) do
      PubSub.subscribe(pubsub_server, topic)
    else
      sender = {__MODULE__, {transport_pid, serializer, channel.__intercepts__()}}
      PubSub.subscribe(pubsub_server, topic, sender: sender)
    end

    Process.put(:"$phx_transport_ref", transport_ref)
    {:noreply, %{socket | joined: true}}
  end

  ## Handle results

  defp handle_result({:stop, reason, socket}, _callback) do
    case reason do
      :normal -> send_socket_close(socket, reason)
      :shutdown -> send_socket_close(socket, reason)
      {:shutdown, _} -> send_socket_close(socket, reason)
      _ -> :noop
    end

    {:stop, reason, socket}
  end

  defp handle_result({:reply, resp, socket}, :handle_call) do
    {:reply, resp, socket}
  end

  defp handle_result({:noreply, socket}, callback)
       when callback in [:handle_call, :handle_cast] do
    {:noreply, socket}
  end

  defp handle_result({:noreply, socket}, _callback) do
    {:noreply, put_in(socket.ref, nil)}
  end

  defp handle_result({:noreply, socket, timeout_or_hibernate}, _callback) do
    {:noreply, put_in(socket.ref, nil), timeout_or_hibernate}
  end

  defp handle_result(result, :handle_in) do
    raise """
    Expected handle_in/3 to return one of:

        {:noreply, Socket.t} |
        {:noreply, Socket.t, timeout | :hibernate} |
        {:reply, {status :: atom, response :: map}, Socket.t} |
        {:reply, status :: atom, Socket.t} |
        {:stop, reason :: term, Socket.t} |
        {:stop, reason :: term, {status :: atom, response :: map}, Socket.t} |
        {:stop, reason :: term, status :: atom, Socket.t}

    got #{inspect(result)}
    """
  end

  defp handle_result(result, callback) do
    raise """
    Expected #{callback} to return one of:

        {:noreply, Socket.t} |
        {:noreply, Socket.t, timeout | :hibernate} |
        {:stop, reason :: term, Socket.t} |

    got #{inspect(result)}
    """
  end

  defp send_socket_close(%{transport_pid: transport_pid}, reason) do
    send(transport_pid, {:socket_close, self(), reason})
  end

  ## Handle in/replies

  defp handle_in({:reply, reply, %Socket{} = socket}) do
    handle_reply(socket, reply)
    {:noreply, put_in(socket.ref, nil)}
  end

  defp handle_in({:stop, reason, reply, socket}) do
    handle_reply(socket, reply)
    handle_result({:stop, reason, socket}, :handle_in)
  end

  defp handle_in(other) do
    handle_result(other, :handle_in)
  end

  defp handle_reply(socket, {status, payload}) when is_atom(status) do
    reply(
      socket.transport_pid,
      socket.join_ref,
      socket.ref,
      socket.topic,
      {status, payload},
      socket.serializer
    )
  end

  defp handle_reply(socket, status) when is_atom(status) do
    handle_reply(socket, {status, %{}})
  end

  defp handle_reply(_socket, reply) do
    raise """
    Channel replies from handle_in/3 are expected to be one of:

        status :: atom
        {status :: atom, response :: map}

    for example:

        {:reply, :ok, socket}
        {:reply, {:ok, %{}}, socket}
        {:stop, :shutdown, {:error, %{}}, socket}

    got #{inspect(reply)}
    """
  end

  defp warn_unexpected_msg(fun, arity, msg, channel) do
    proc =
      case Process.info(self(), :registered_name) do
        {_, []} -> self()
        {_, name} -> name
      end

    :error_logger.warning_msg(
      ~c"~p ~p received unexpected message in #{fun}/#{arity}: ~p~n",
      [channel, proc, msg]
    )
  end
end
