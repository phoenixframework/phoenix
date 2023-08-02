defmodule Phoenix.Router.ConsoleFormatter do
  @moduledoc false

  @doc """
  Format the routes for printing.
  """

  @socket_verb "WS"

  @longpoll_verbs ["GET", "POST"]

  def format(router, endpoint \\ nil) do
    routes = Phoenix.Router.routes(router)
    column_widths = calculate_column_widths(router, routes, endpoint)

    routes
    |> Enum.map_join("", &format_route(&1, router, column_widths))
    |> Kernel.<>(format_endpoint(endpoint, router, column_widths))
  end

  defp format_endpoint(nil, _router, _), do: ""
  defp format_endpoint(endpoint, router, widths) do
    case endpoint.__sockets__() do
      [] -> ""
      sockets ->
        Enum.map_join(sockets, "", fn socket ->
          format_websocket(socket, router, widths) <>
          format_longpoll(socket, router, widths)
        end)
      end
  end

  defp format_websocket({_path, Phoenix.LiveReloader.Socket, _opts}, _router, _), do: ""
  defp format_websocket({path, module, opts}, router, widths) do
    if opts[:websocket] != false do
      prefix = if router.__helpers__(), do: "websocket", else: ""
      {verb_len, path_len, route_name_len} = widths

      String.pad_leading(prefix, route_name_len) <> "  " <>
      String.pad_trailing(@socket_verb, verb_len) <> "  " <>
      String.pad_trailing(path <> "/websocket", path_len) <> "  " <>
      inspect(module) <>
      "\n"
    else
      ""
    end
  end

  defp format_longpoll({_path, Phoenix.LiveReloader.Socket, _opts}, _router, _), do: ""
  defp format_longpoll({path, module, opts}, router, widths) do
    if opts[:longpoll] != false do
      prefix = if router.__helpers__(), do: "longpoll", else: ""
      for method <- @longpoll_verbs, into: "" do
        {verb_len, path_len, route_name_len} = widths

        String.pad_leading(prefix, route_name_len) <> "  " <>
        String.pad_trailing(method, verb_len) <> "  " <>
        String.pad_trailing(path <> "/longpoll", path_len) <> "  " <>
        inspect(module) <>
        "\n"
      end
    else
      ""
    end
  end

  defp calculate_column_widths(router, routes, endpoint) do
    sockets = endpoint && endpoint.__sockets__() || []

    widths =
      Enum.reduce(routes, {0, 0, 0}, fn route, acc ->
        %{verb: verb, path: path, helper: helper} = route
        verb = verb_name(verb)
        {verb_len, path_len, route_name_len} = acc
        route_name = route_name(router, helper)
        {max(verb_len, String.length(verb)),
        max(path_len, String.length(path)),
        max(route_name_len, String.length(route_name))}
      end)

    Enum.reduce(sockets, widths, fn {path, _mod, opts}, acc ->
      {verb_len, path_len, route_name_len} = acc
      prefix = if router.__helpers__(), do: "websocket", else: ""
      verb_length = socket_verbs(opts) |> Enum.map(&String.length/1) |> Enum.max(&>=/2, fn -> 0 end)

      {max(verb_len, verb_length),
      max(path_len, String.length(path <> "/websocket")),
      max(route_name_len, String.length(prefix))}
    end)
  end

  defp format_route(route, router, column_widths) do
    %{verb: verb, path: path, plug: plug, metadata: metadata, plug_opts: plug_opts, helper: helper} = route
    verb = verb_name(verb)
    route_name = route_name(router, helper)
    {verb_len, path_len, route_name_len} = column_widths
    log_module = metadata[:log_module] || plug

    String.pad_leading(route_name, route_name_len) <> "  " <>
    String.pad_trailing(verb, verb_len) <> "  " <>
    String.pad_trailing(path, path_len) <> "  " <>
    "#{inspect(log_module)} #{inspect(plug_opts)}\n"
  end

  defp route_name(_router, nil),  do: ""
  defp route_name(router, name) do
    if router.__helpers__() do
      name <> "_path"
    else
      ""
    end
  end

  defp verb_name(verb), do: verb |> to_string() |> String.upcase()

  defp socket_verbs(socket_opts) do
    if socket_opts[:longpoll] != false do
      [@socket_verb | @longpoll_verbs]
    else
      [@socket_verb]
    end
  end
end
