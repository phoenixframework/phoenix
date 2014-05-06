defmodule Phoenix.Router.Socket do

  defmacro __using__(options) do
    mount = Dict.fetch! options, :mount

    quote do
      import unquote(__MODULE__)
      dispatch_option unquote(mount), Phoenix.Socket.Handler, router: __MODULE__
    end
  end

  defmacro channel(channel, module) do
    quote do
      def match(socket, :websocket, unquote(channel), "join", message) do
        apply(unquote(module), :join, [socket, socket.topic, message])
      end
      def match(socket, :websocket, unquote(channel), "leave", message) do
        apply(unquote(module), :leave, [socket, message])
      end
      def match(socket, :websocket, unquote(channel), event, message) do
        apply(unquote(module), :event, [event, socket, message])
      end
    end
  end
end
