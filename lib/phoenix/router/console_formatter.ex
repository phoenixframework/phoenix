defmodule Phoenix.Router.ConsoleFormatter do
  @moduledoc false
  alias Phoenix.Router.Route

  @doc """
  Format the routes for printing.
  """
  def format(router) do
    routes = user_defined_routes(router)
    column_widths = calculate_column_widths(routes)
    Enum.map_join(routes, "", &format_route(&1, column_widths))
  end

  defp user_defined_routes(router) do
    router.__routes__
    |> Enum.reject(fn route ->
      route.controller |> to_string |> String.starts_with?("Elixir.Phoenix.Transports")
    end)
  end

  defp calculate_column_widths(routes) do
    Enum.reduce routes, {0, 0, 0}, fn(route, acc) ->
      %Route{verb: verb, path: path, helper: helper} = route
      {verb_len, path_len, route_name_len} = acc
      route_name = route_name(helper)

      {max(verb_len, String.length(verb)),
       max(path_len, String.length(path)),
       max(route_name_len, String.length(route_name))}
    end
  end

  defp format_route(route, column_widths) do
    %Route{verb: verb, path: path, controller: controller,
           action: action, helper: helper} = route
    route_name = route_name(helper)
    {verb_len, path_len, route_name_len} = column_widths

    String.rjust(route_name, route_name_len) <> "  " <>
    String.ljust(verb, verb_len) <> "  " <>
    String.ljust(path, path_len) <> "  " <>
    inspect(controller) <> "." <> Atom.to_string(action) <> "/2\n"
  end

  defp route_name(nil),  do: ""
  defp route_name(name), do: name <> "_path"
end
