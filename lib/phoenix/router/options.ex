defmodule Phoenix.Router.Options do
  alias Phoenix.Config

  def merge(options, dispatch_options, router_module, adapter) do
    Config.for(router_module).router
    |> map_config
    |> Dict.merge(options)
    |> adapter.merge_options(dispatch_options, router_module)
  end

  defp map_config([]), do: []
  defp map_config([{k, v}|t]), do: [option(k,v)] ++ map_config(t)

  defp option(:port, val), do: { :port, convert(:int, val) }
  defp option(key, val), do: { key, val }

  defp convert(:int, val) when is_integer(val), do: val
  defp convert(:int, val), do: String.to_integer(val)
end
