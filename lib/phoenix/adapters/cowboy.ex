defmodule Phoenix.Adapters.Cowboy do

  @doc """
  Merge Router options with raw dispatch_options for Cowboy adapter

    * plug_options - The options List provided to `use Phoenix.Router`
    * dispatch_options - The raw ptions, from the `dispatch_options` macro
    * module - The router module

  """
  def merge_options(plug_options, dispatch_options, module) do
    dispatch = Enum.concat [dispatch_options,
                            Dict.get(plug_options, :dispatch, []),
                            [{:_, Plug.Adapters.Cowboy.Handler, { module, [] }}]]

    Dict.put(plug_options, :dispatch, [{:_, dispatch}])
  end

  defmacro __using__(_options) do
    quote do
      Module.register_attribute __MODULE__, :dispatch_options, accumulate: true,
                                                               persist: false
      import unquote(__MODULE__)
    end
  end

  defmacro dispatch_option(path, handler, options \\ []) do
    quote do
      @dispatch_options {unquote(path), unquote(handler), unquote(options)}
    end
  end
end
