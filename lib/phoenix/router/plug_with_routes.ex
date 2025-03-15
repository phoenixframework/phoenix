defmodule Phoenix.Router.PlugWithRoutes do
  @type custom_route_info :: %{verb: String.t(), path: String.t(), label: String.t()}
  @callback phoenix_routes(any) :: [custom_route_info]

  def verify_route(plug, opts, path) do
    opts
    |> plug.phoenix_routes()
    |> Enum.map(fn route -> 
      case Path.split(route.path) do
        ["/" | rest] -> rest
        path -> path
      end
    end)
    |> Enum.any?(&match_path?(&1, path))
  end

  defp match_path?([], []), do: true
  defp match_path?([], _), do: false
  defp match_path?(_, []), do: false
  defp match_path?([":" <> _ | rest_route], [_ | rest_path]) do
    match_path?(rest_route, rest_path)
  end

  defp match_path?(["_" <> _ | rest_route], [_ | rest_path]) do
    match_path?(rest_route, rest_path)
  end

  defp match_path?(["*" <> _], _) do
    true
  end

  defp match_path?([same | rest_path], [same | rest_route]) do
    match_path?(rest_path, rest_route)
  end

  defp match_path?(_, _) do
    false
  end
end
