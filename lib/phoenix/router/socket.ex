defmodule Phoenix.Router.Socket do

  defmacro __using__(_opts) do
    quote do
      router = __MODULE__
      import unquote(__MODULE__)
      defmodule Socket do
        use Phoenix.Websocket.Handler, router: router
      end
    end
  end

  defmacro channel(channel, module) do
    quote do
      def match(req, :websocket, unquote(channel), "join", data, state) do
        apply(unquote(module), :join, [req, id])
      end
      def match(req, :websocket, unquote(channel), "leave", data, state) do
        apply(unquote(module), :leave, [req, id])
      end
      def match(req, :websocket, unquote(channel), event, data, state) do
        apply(unquote(module), :event, [event, req, id])
      end
    end
  end
end
