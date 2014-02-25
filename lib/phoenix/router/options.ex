defmodule Phoenix.Router.Options do
  alias Phoenix.Config

  def merge(options, module) do
    Config.for(module).router |> map_config |> Dict.merge(options)
  end

  defp map_config([]), do: []
  defp map_config([{k, v}|t]), do: [option(k,v)] ++ map_config(t)

  defp option(:port, val), do: { :port, convert(:int, val) }
  defp option(key, val), do: { key, val }

  defp convert(:int, val) when is_integer(val), do: val
  defp convert(:int, val), do: binary_to_integer(val)
end
