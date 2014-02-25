defmodule Phoenix.Adapters.Cowboy do
  def setup_options(module, options, dispatch_options) do
    dispatch = Enum.concat [dispatch_options,
                            Dict.get(options, :dispatch, []), 
                            [{:_, Plug.Adapters.Cowboy.Handler, { module, [] }}]]

    Dict.put(options, :dispatch, [{:_, dispatch}])
  end

  defmacro __using__(_options) do
    quote do
      Module.register_attribute __MODULE__, :dispatch_options, accumulate: true, 
                                                               persist: false
      import unquote(__MODULE__)
    end
  end
  defmacro cowboy_dispatch(path, handler, options \\ []) do
    quote do
      @dispatch_options {unquote(path), unquote(handler), unquote(options)}
    end
  end
end
