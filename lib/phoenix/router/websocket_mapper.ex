defmodule Phoenix.Router.RawWebsocketMapper do
  defmacro raw_websocket(path, handler, options \\ []) do
    quote do
      cowboy_dispatch unquote(path), unquote(handler), unquote(options)
    end
  end
end
