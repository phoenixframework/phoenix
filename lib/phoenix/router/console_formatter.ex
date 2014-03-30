defmodule Phoenix.Router.ConsoleFormatter do
  alias Phoenix.Project

  def default_router do
    Project.module_root.Config.Router
  end

  def format(router) do
    routes = router.__routes__

    Enum.join(format_routes(routes), "\n")
  end

  def format_routes(routes) do
    column_widths = calculate_column_widths(routes)

    lc route inlist routes, do: format_route(route, column_widths)
  end

  defp calculate_column_widths(routes) do
    Enum.reduce routes, [0, 0, 0], fn(route, acc) ->
      {method, path, _controller, _action, options} = route
      [method_len, path_len, route_name_len] = acc
      route_name = Keyword.get(options, :as, :"")

      [max(method_len, String.length(to_string(method))),
        max(path_len, String.length(path)),
        max(route_name_len, String.length(to_string(route_name)))]
    end
  end

  defp format_route(route, column_widths) do
    {method, path, controller, action, options} = route
    route_name = Keyword.get(options, :as, :"")
    [method_len, path_len, route_name_len] = column_widths

    controller_name = String.replace(to_string(controller),
    to_string(Project.module_root.Controllers) <> ".",
    "")

    String.rjust(to_string(route_name), route_name_len) <> "  " <>
    String.ljust(String.upcase(to_string(method)), method_len) <> "  " <>
    String.ljust(path, path_len) <> "  " <>
    controller_name <> "#" <> to_string(action)
  end
end
