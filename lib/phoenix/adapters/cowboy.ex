defmodule Phoenix.Adapters.Cowboy do
  def setup_options(module, options, dispatch_options) do
    dispatch = Enum.concat [dispatch_options,
                            Dict.get(options, :dispatch, []), 
                            [{:_, Plug.Adapters.Cowboy.Handler, { module, [] }}]]

    Dict.put(options, :dispatch, [{:_, dispatch}])
  end
end
