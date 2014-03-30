defmodule Phoenix.Channel do
  alias Phoenix.Topic
  alias Phoenix.Socket

  defmacro __using__(options) do
    channel = Dict.fetch! options, :channel

    quote do
      import unquote(__MODULE__)
      @channel unquote(channel)

      def channel, do: @channel

      # def call(:join, socket, message) do
      #   join(socket, message)
      # end
      # def call(:leave, socket, message) do
      #   if authenticated?(socket, @channel) do
      #     leave(socket, message)
      #   else
      #     {:error, socket, :unauthenticated}
      #   end
      # end
      # def call(:event, event, socket, message) do
      #   if authenticated?(socket, @channel) do
      #     event(event, socket, message)
      #   else
      #     {:error, socket, :unauthenticated}
      #   end
      # end
    end
  end

  def subscribe(topic, socket) do
    Topic.subscribe(topic, socket.pid)
  end

  def broadcast(topic, message) do
    broadcast_from :global, topic, message
  end

  def broadcast_from(:global, topic, message) do
    Topic.broadcast_from(:global, topic, reply_json(message))
  end
  def broadcast_from(socket, topic, message) do
    Topic.broadcast_from(socket.pid, topic, reply_json(message))
  end

  def reply(socket, message) do
    send socket.pid, {:reply, {:text, JSON.encode!(message)}}
    {:ok, socket}
  end

  def reply_json(message) do
    {:reply, {:text, JSON.encode!(message)}}
  end
end
