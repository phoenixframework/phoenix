defmodule Phoenix.Socket.V2.JSONSerializer do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer

  @push 0
  @reply 1
  @broadcast 2

  alias Phoenix.Socket.{Broadcast, Message, Reply}

  @impl true
  def fastlane!(%Broadcast{payload: {:binary, data}} = msg) do
    topic_size = byte_size!(msg.topic, :topic, 255)
    event_size = byte_size!(msg.event, :event, 255)

    bin = <<
      @broadcast::size(8),
      topic_size::size(8),
      event_size::size(8),
      msg.topic::binary-size(topic_size),
      msg.event::binary-size(event_size),
      data::binary
    >>

    {:socket_push, :binary, bin}
  end

  def fastlane!(%Broadcast{payload: %{}} = msg) do
    data = Phoenix.json_library().encode_to_iodata!([nil, nil, msg.topic, msg.event, msg.payload])
    {:socket_push, :text, data}
  end

  def fastlane!(%Broadcast{payload: invalid}) do
    raise ArgumentError, "expected broadcasted payload to be a map, got: #{inspect(invalid)}"
  end

  @impl true
  def encode!(%Reply{payload: {:binary, data}} = reply) do
    status = to_string(reply.status)
    join_ref = to_string(reply.join_ref)
    ref = to_string(reply.ref)
    join_ref_size = byte_size!(join_ref, :join_ref, 255)
    ref_size = byte_size!(ref, :ref, 255)
    topic_size = byte_size!(reply.topic, :topic, 255)
    status_size = byte_size!(status, :status, 255)

    bin = <<
      @reply::size(8),
      join_ref_size::size(8),
      ref_size::size(8),
      topic_size::size(8),
      status_size::size(8),
      join_ref::binary-size(join_ref_size),
      ref::binary-size(ref_size),
      reply.topic::binary-size(topic_size),
      status::binary-size(status_size),
      data::binary
    >>

    {:socket_push, :binary, bin}
  end

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

  def encode!(%Message{payload: {:binary, data}} = msg) do
    join_ref = to_string(msg.join_ref)
    join_ref_size = byte_size!(join_ref, :join_ref, 255)
    topic_size = byte_size!(msg.topic, :topic, 255)
    event_size = byte_size!(msg.event, :event, 255)

    bin = <<
      @push::size(8),
      join_ref_size::size(8),
      topic_size::size(8),
      event_size::size(8),
      join_ref::binary-size(join_ref_size),
      msg.topic::binary-size(topic_size),
      msg.event::binary-size(event_size),
      data::binary
    >>

    {:socket_push, :binary, bin}
  end

  def encode!(%Message{payload: %{}} = msg) do
    data = [msg.join_ref, msg.ref, msg.topic, msg.event, msg.payload]
    {:socket_push, :text, Phoenix.json_library().encode_to_iodata!(data)}
  end

  def encode!(%Message{payload: invalid}) do
    raise ArgumentError, "expected payload to be a map, got: #{inspect(invalid)}"
  end

  @impl true
  def decode!(raw_message, opts) do
    case Keyword.fetch(opts, :opcode) do
      {:ok, :text} -> decode_text(raw_message)
      {:ok, :binary} -> decode_binary(raw_message)
    end
  end

  defp decode_text(raw_message) do
    [join_ref, ref, topic, event, payload | _] = Phoenix.json_library().decode!(raw_message)

    %Message{
      topic: topic,
      event: event,
      payload: payload,
      ref: ref,
      join_ref: join_ref
    }
  end

  defp decode_binary(<<
         @push::size(8),
         join_ref_size::size(8),
         ref_size::size(8),
         topic_size::size(8),
         event_size::size(8),
         join_ref::binary-size(join_ref_size),
         ref::binary-size(ref_size),
         topic::binary-size(topic_size),
         event::binary-size(event_size),
         data::binary
       >>) do
    %Message{
      topic: topic,
      event: event,
      payload: {:binary, data},
      ref: ref,
      join_ref: join_ref
    }
  end

  defp byte_size!(bin, kind, max) do
    case byte_size(bin) do
      size when size <= max ->
        size

      oversized ->
        raise ArgumentError, """
        unable to convert #{kind} to binary.

            #{inspect(bin)}

        must be less than or equal to #{max} bytes, but is #{oversized} bytes.
        """
    end
  end
end
