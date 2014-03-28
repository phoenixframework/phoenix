defmodule Phoenix.Router.RawWebsocketMapper do
  defmacro raw_websocket(path, handler, options \\ []) do
    quote do
      dispatch_option unquote(path), unquote(handler), unquote(options)
    end
  end
end
