defmodule Phoenix.Router.ConsoleFormatter do
  @moduledoc false

  @doc """
  Format the routes for printing.
  """
  def format(router, endpoint \\ nil) do
    routes = Phoenix.Router.routes(router)
    column_widths = calculate_column_widths(routes, endpoint)

    routes
    |> Enum.map_join("", &format_route(&1, column_widths))
    |> Kernel.<>(format_endpoint(endpoint, column_widths))
  end

  defp format_endpoint(nil, _), do: ""
  defp format_endpoint(endpoint, widths) do
    case endpoint.__sockets__() do
      [] -> ""
      sockets ->
        Enum.map_join(sockets, "", fn socket ->
          format_websocket(socket, widths) <>
          format_longpoll(socket, widths)
        end)
      end
  end

  defp format_websocket({_path, Phoenix.LiveReloader.Socket, _opts}, _), do: ""
  defp format_websocket({path, module, opts}, widths) do
    if opts[:websocket] != false do
      {verb_len, path_len, route_name_len} = widths

      String.pad_leading("websocket", route_name_len) <> "  " <>
      String.pad_trailing("WS", verb_len) <> "  " <>
      String.pad_trailing(path <> "/websocket", path_len) <> "  " <>
      inspect(module) <>
      "\n"
    else
      ""
    end
  end

  defp format_longpoll({_path, Phoenix.LiveReloader.Socket, _opts}, _), do: ""
  defp format_longpoll({path, module, opts}, widths) do
    if opts[:longpoll] != false do
      for method <- ["GET", "POST"], into: "" do
        {verb_len, path_len, route_name_len} = widths

        String.pad_leading("longpoll", route_name_len) <> "  " <>
        String.pad_trailing(method, verb_len) <> "  " <>
        String.pad_trailing(path <> "/longpoll", path_len) <> "  " <>
        inspect(module) <>
        "\n"
      end
    else
      ""
    end
  end

  defp calculate_column_widths(routes, endpoint) do
    sockets = endpoint && endpoint.__sockets__() || []

    widths =
      Enum.reduce(routes, {0, 0, 0}, fn route, acc ->
        %{verb: verb, path: path, helper: helper} = route
        verb = verb_name(verb)
        {verb_len, path_len, route_name_len} = acc
        route_name = route_name(helper)

        {max(verb_len, String.length(verb)),
        max(path_len, String.length(path)),
        max(route_name_len, String.length(route_name))}
      end)

    Enum.reduce(sockets, widths, fn {path, _mod, _opts}, acc ->
      {verb_len, path_len, route_name_len} = acc

      {verb_len,
       max(path_len, String.length(path <> "/websocket")),
       max(route_name_len, String.length("websocket"))}
    end)
  end

  defp format_route(route, column_widths) do
    %{verb: verb, path: path, plug: plug, plug_opts: plug_opts, helper: helper} = route
    verb = verb_name(verb)
    route_name = route_name(helper)
    {verb_len, path_len, route_name_len} = column_widths

    String.pad_leading(route_name, route_name_len) <> "  " <>
    String.pad_trailing(verb, verb_len) <> "  " <>
    String.pad_trailing(path, path_len) <> "  " <>
    "#{inspect(plug)} #{inspect(plug_opts)}\n"
  end

  defp route_name(nil),  do: ""
  defp route_name(name), do: name <> "_path"

  defp verb_name(verb), do: verb |> to_string() |> String.upcase()
end
