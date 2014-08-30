defmodule Phoenix.Router.ConsoleFormatter do
  alias Phoenix.Naming

  @doc """
  Returns the default Application router, ie `MyApp.Router`
  """
  def default_router do
    Module.concat(Phoenix.Project.module_root, Router)
  end


  @doc false
  def format(router) do
    routes = router.__routes__

    Enum.join(format_routes(routes), "\n")
  end

  @doc false
  def format_routes(routes) do
    column_widths = calculate_column_widths(routes)

    for route <- routes, do: format_route(route, column_widths)
  end

  defp calculate_column_widths(routes) do
    Enum.reduce routes, [0, 0, 0], fn(route, acc) ->
      {method, path, _controller, _action, options} = route
      [method_len, path_len, route_name_len] = acc
      route_name = route_name(Keyword.get(options, :as))

      [max(method_len, String.length(to_string(method))),
        max(path_len, String.length(path)),
        max(route_name_len, String.length(to_string(route_name)))]
    end
  end

  defp format_route(route, column_widths) do
    {method, path, controller, action, options} = route
    route_name = route_name(Keyword.get(options, :as))
    [method_len, path_len, route_name_len] = column_widths
    controller_name = controller |> to_string |> Naming.module_name

    String.rjust(route_name, route_name_len) <> "  " <>
    String.ljust(String.upcase(to_string(method)), method_len) <> "  " <>
    String.ljust(path, path_len) <> "  " <>
    controller_name <> "." <> to_string(action) <> "/2"
  end
  defp route_name(nil), do: ""
  defp route_name(name), do: to_string(name) <> "_path"
end
