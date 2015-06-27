defmodule Phoenix.Router.ConsoleFormatter do
  @moduledoc false
  alias Phoenix.Router.Route

  @doc """
  Format the routes for printing.
  """
  def format(router) do
    routes = router.__routes__
    column_widths = calculate_column_widths(routes)
    Enum.map_join(routes, "", &format_route(&1, column_widths))
  end

  defp calculate_column_widths(routes) do
    Enum.reduce routes, {0, 0, 0}, fn(route, acc) ->
      %Route{verb: verb, path: path, helper: helper} = route
      verb = verb_name(verb)
      {verb_len, path_len, route_name_len} = acc
      route_name = route_name(helper)

      {max(verb_len, String.length(verb)),
       max(path_len, String.length(path)),
       max(route_name_len, String.length(route_name))}
    end
  end

  defp format_route(route, column_widths) do
    %Route{verb: verb, path: path, plug: plug,
           opts: opts, helper: helper} = route
    verb = verb_name(verb)
    route_name = route_name(helper)
    {verb_len, path_len, route_name_len} = column_widths

    String.rjust(route_name, route_name_len) <> "  " <>
    String.ljust(verb, verb_len) <> "  " <>
    String.ljust(path, path_len) <> "  " <>
    "#{inspect(plug)} #{inspect(opts)}\n"
  end

  defp route_name(nil),  do: ""
  defp route_name(name), do: name <> "_path"

  defp verb_name(verb), do: verb |> to_string() |> String.upcase()
end
