defmodule Phoenix.Socket.V2.JSONSerializer do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.{Broadcast, Message, Reply}

  @impl true
  def fastlane!(%Broadcast{} = msg) do
    data = Phoenix.json_library().encode_to_iodata!([nil, nil, msg.topic, msg.event, msg.payload])
    {:socket_push, :text, data}
  end

  @impl true
  def encode!(%Reply{} = reply) do
    data = [
      reply.join_ref,
      reply.ref,
      reply.topic,
      "phx_reply",
      %{status: reply.status, response: reply.payload}
    ]

    {:socket_push, :text, Phoenix.json_library().encode_to_iodata!(data)}
  end

  def encode!(%Message{} = msg) do
    data = [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload]
    {:socket_push, :text, Phoenix.json_library().encode_to_iodata!(data)}
  end

  @impl true
  def decode!(raw_message, _opts) do
    [join_ref, ref, topic, event, payload | _] = Phoenix.json_library().decode!(raw_message)

    %Message{
      topic: topic,
      event: event,
      payload: payload,
      ref: ref,
      join_ref: join_ref
    }
  end
end
