defmodule Phoenix.Socket.TransportDispatcher do
  @moduledoc """
  Callback module for dispatching `Phoenix.Socket.Message` to a channel.

  This module handles incoming events:

    * "hearteat" events in the "phoenix" topic - emits OK reploy
    * "phx_join" on any topic - joins socket to topic
    * any event with topic matching joined channels - sends event to channel
    * any other topics - replies with `unmatched_topic` error
  """
  alias Phoenix.Socket
  alias Phoenix.Socket.{Reply, Message}

  require Logger

  @doc false
  def dispatch(%{ref: ref, topic: "phoenix", event: "heartbeat"}, _channels, socket) do
    {:reply, %Reply{join_ref: socket.join_ref, ref: ref, topic: "phoenix", status: :ok, payload: %{}}}
  end

  @doc false
  def dispatch(%Message{} = msg, channels, socket) do
    channels
    |> Map.get(msg.topic)
    |> do_dispatch(msg, socket)
  end

  @doc false
  def build_channel_socket(%Socket{} = socket, channel, topic, join_ref, opts) do
    %Socket{socket |
            topic: topic,
            channel: channel,
            join_ref: join_ref,
            assigns: Map.merge(socket.assigns, opts[:assigns] || %{}),
            private: channel.__socket__(:private)}
  end

  @doc false
  def on_exit_message(topic, join_ref) do
    %Message{join_ref: join_ref, ref: join_ref, topic: topic, event: "phx_error", payload: %{}}
  end

  @doc false
  def on_graceful_exit_message(topic, ref) do
    %Message{join_ref: ref, ref: ref, topic: topic, event: "phx_close", payload: %{}}
  end

  defp do_dispatch(nil, %{event: "phx_join", topic: topic} = msg, base_socket) do
    case base_socket.handler.__channel__(topic, base_socket.transport_name) do
      {channel, opts} ->
        socket = build_channel_socket(base_socket, channel, topic, msg.ref, opts)

        case Phoenix.Channel.Server.join(socket, msg.payload) do
          {:ok, response, pid} ->
            log socket, topic, fn -> "Replied #{topic} :ok" end
            {:joined, pid, %Reply{join_ref: socket.join_ref, ref: msg.ref, topic: topic, status: :ok, payload: response}}

          {:error, reason} ->
            log socket, topic, fn -> "Replied #{topic} :error" end
            {:error, reason, %Reply{join_ref: socket.join_ref, ref: msg.ref, topic: topic, status: :error, payload: reason}}
        end

      nil -> reply_ignore(msg, base_socket)
    end
  end

  defp do_dispatch(pid, %{event: "phx_join"} = msg, socket) when is_pid(pid) do
    Logger.debug "Duplicate channel join for topic \"#{msg.topic}\" in #{inspect(socket.handler)}. " <>
                 "Closing existing channel for new join."
    :ok = Phoenix.Channel.Server.close(pid)
    do_dispatch(nil, msg, socket)
  end

  defp do_dispatch(nil, msg, socket) do
    reply_ignore(msg, socket)
  end

  defp do_dispatch(channel_pid, msg, _socket) do
    send(channel_pid, msg)
    :noreply
  end

  defp log(_, "phoenix" <> _, _func), do: :noop
  defp log(%{ private: %{ log_join: false } }, _topic, _func), do: :noop
  defp log(%{ private: %{ log_join: level } }, _topic, func), do: Logger.log(level, func)

  defp reply_ignore(msg, socket) do
    Logger.warn fn -> "Ignoring unmatched topic \"#{msg.topic}\" in #{inspect(socket.handler)}" end
    {:error, :unmatched_topic, %Reply{join_ref: socket.join_ref, ref: msg.ref, topic: msg.topic, status: :error,
                                      payload: %{reason: "unmatched topic"}}}
  end
end
