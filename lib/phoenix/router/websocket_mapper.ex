defmodule Phoenix.Router.WebsocketMapper do
  defmacro __using__(_options) do
    quote do
      Module.register_attribute __MODULE__, :dispatch_options, accumulate: true, 
                                                               persist: false
      import unquote(__MODULE__)
    end
  end

  defmacro websocket(path, handler, options \\ []) do
    quote do
      @dispatch_options {unquote(path), unquote(handler), unquote(options) }
    end
  end
end
