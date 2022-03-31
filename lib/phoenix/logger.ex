defmodule Phoenix.Logger do
  @moduledoc """
  Instrumenter to handle logging of various instrumentation events.

  ## Instrumentation

  Phoenix uses the `:telemetry` library for instrumentation. The following events
  are published by Phoenix with the following measurements and metadata:

    * `[:phoenix, :endpoint, :start]` - dispatched by `Plug.Telemetry` in your endpoint,
      usually after code reloading
      * Measurement: `%{system_time: system_time}`
      * Metadata: `%{conn: Plug.Conn.t, options: Keyword.t}`
      * Options: `%{log: Logger.level | false}`
      * Disable logging: In your endpoint `plug Plug.Telemetry, ..., log: Logger.level | false`
      * Configure log level dynamically: `plug Plug.Telemetry, ..., log: {Mod, Fun, Args}`

    * `[:phoenix, :endpoint, :stop]` - dispatched by `Plug.Telemetry` in your
      endpoint whenever the response is sent
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{conn: Plug.Conn.t, options: Keyword.t}`
      * Options: `%{log: Logger.level | false}`
      * Disable logging: In your endpoint `plug Plug.Telemetry, ..., log: Logger.level | false`
      * Configure log level dynamically: `plug Plug.Telemetry, ..., log: {Mod, Fun, Args}`

    * `[:phoenix, :router_dispatch, :start]` - dispatched by `Phoenix.Router`
      before dispatching to a matched route
      * Measurement: `%{system_time: System.system_time}`
      * Metadata: `%{conn: Plug.Conn.t, route: binary, plug: module, plug_opts: term, path_params: map, pipe_through: [atom], log: Logger.level | false}`
      * Disable logging: Pass `log: false` to the router macro, for example: `get("/page", PageController, :index, log: false)`
      * Configure log level dynamically: `get("/page", PageController, :index, log: {Mod, Fun, Args})`

    * `[:phoenix, :router_dispatch, :exception]` - dispatched by `Phoenix.Router`
      after exceptions on dispatching a route
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{conn: Plug.Conn.t, kind: :throw | :error | :exit, reason: term(), stacktrace: Exception.stacktrace()}`
      * Disable logging: This event is not logged

    * `[:phoenix, :router_dispatch, :stop]` - dispatched by `Phoenix.Router`
      after successfully dispatching a matched route
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{conn: Plug.Conn.t, route: binary, plug: module, plug_opts: term, path_params: map, pipe_through: [atom], log: Logger.level | false}`
      * Disable logging: This event is not logged

    * `[:phoenix, :error_rendered]` - dispatched at the end of an error view being rendered
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{conn: Plug.Conn.t, status: Plug.Conn.status, kind: Exception.kind, reason: term, stacktrace: Exception.stacktrace}`
      * Disable logging: Set `render_errors: [log: false]` on your endpoint configuration

    * `[:phoenix, :socket_connected]` - dispatched by `Phoenix.Socket`, at the end of a socket connection
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{endpoint: atom, transport: atom, params: term, connect_info: map, vsn: binary, user_socket: atom, result: :ok | :error, serializer: atom, log: Logger.level | false}`
      * Disable logging: `use Phoenix.Socket, log: false` or `socket "/foo", MySocket, websocket: [log: false]` in your endpoint

    * `[:phoenix, :channel_joined]` - dispatched at the end of a channel join
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{result: :ok | :error, params: term, socket: Phoenix.Socket.t}`
      * Disable logging: This event cannot be disabled

    * `[:phoenix, :channel_handled_in]` - dispatched at the end of a channel handle in
      * Measurement: `%{duration: native_time}`
      * Metadata: `%{event: binary, params: term, socket: Phoenix.Socket.t}`
      * Disable logging: This event cannot be disabled

  To see an example of how Phoenix LiveDashboard uses these events to create
  metrics, visit <https://hexdocs.pm/phoenix_live_dashboard/metrics.html>.

  ## Parameter filtering

  When logging parameters, Phoenix can filter out sensitive parameters
  such as passwords and tokens. Parameters to be filtered can be
  added via the `:filter_parameters` option:

      config :phoenix, :filter_parameters, ["password", "secret"]

  With the configuration above, Phoenix will filter any parameter
  that contains the terms `password` or `secret`. The match is
  case sensitive.

  Phoenix's default is `["password"]`.

  Phoenix can filter all parameters by default and selectively keep
  parameters. This can be configured like so:

      config :phoenix, :filter_parameters, {:keep, ["id", "order"]}

  With the configuration above, Phoenix will filter all parameters,
  except those that match exactly `id` or `order`. If a kept parameter
  matches, all parameters nested under that one will also be kept.

  ## Dynamic log level

  In some cases you may wish to set the log level dynamically
  on a per-request basis. To do so, set the `:log` option to
  a tuple, `{Mod, Fun, Args}`. The `Plug.Conn.t()` for the
  request will be prepended to the provided list of arguments.

  When invoked, your function must return a
  [`Logger.level()`](`t:Logger.level()/0`) or `false` to
  disable logging for the request.

  For example, in your Endpoint you might do something like this:

        # lib/my_app_web/endpoint.ex
        plug Plug.Telemetry,
          event_prefix: [:phoenix, :endpoint],
          log: {__MODULE__, :log_level, []}

        # Disables logging for routes like /status/*
        def log_level(%{path_info: ["status" | _]}), do: false
        def log_level(_), do: :info

  ## Disabling

  When you are using custom logging system it is not always desirable to enable
  `#{inspect __MODULE__}` by default. You can always disable this in general by:

      config :phoenix, :logger, false
  """

  require Logger

  @doc false
  def install do
    handlers = %{
      [:phoenix, :endpoint, :start] => &__MODULE__.phoenix_endpoint_start/4,
      [:phoenix, :endpoint, :stop] => &__MODULE__.phoenix_endpoint_stop/4,
      [:phoenix, :router_dispatch, :start] => &__MODULE__.phoenix_router_dispatch_start/4,
      [:phoenix, :error_rendered] => &__MODULE__.phoenix_error_rendered/4,
      [:phoenix, :socket_connected] => &__MODULE__.phoenix_socket_connected/4,
      [:phoenix, :channel_joined] => &__MODULE__.phoenix_channel_joined/4,
      [:phoenix, :channel_handled_in] => &__MODULE__.phoenix_channel_handled_in/4
    }

    for {key, fun} <- handlers do
      :telemetry.attach({__MODULE__, key}, key, fun, :ok)
    end
  end

  @doc false
  def duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end

  @doc false
  def filter_values(values, params \\ Application.get_env(:phoenix, :filter_parameters, []))
  def filter_values(values, {:discard, params}), do: discard_values(values, params)
  def filter_values(values, {:keep, params}), do: keep_values(values, params)
  def filter_values(values, params), do: discard_values(values, params)

  defp discard_values(%{__struct__: mod} = struct, _params) when is_atom(mod) do
    struct
  end

  defp discard_values(%{} = map, params) do
    Enum.into(map, %{}, fn {k, v} ->
      if is_binary(k) and String.contains?(k, params) do
        {k, "[FILTERED]"}
      else
        {k, discard_values(v, params)}
      end
    end)
  end

  defp discard_values([_ | _] = list, params) do
    Enum.map(list, &discard_values(&1, params))
  end

  defp discard_values(other, _params), do: other

  defp keep_values(%{__struct__: mod}, _params) when is_atom(mod), do: "[FILTERED]"

  defp keep_values(%{} = map, params) do
    Enum.into(map, %{}, fn {k, v} ->
      if is_binary(k) and k in params do
        {k, discard_values(v, [])}
      else
        {k, keep_values(v, params)}
      end
    end)
  end

  defp keep_values([_ | _] = list, params) do
    Enum.map(list, &keep_values(&1, params))
  end

  defp keep_values(_other, _params), do: "[FILTERED]"

  defp log_level(nil, _conn), do: :info
  defp log_level(level, _conn) when is_atom(level), do: level

  defp log_level({mod, fun, args}, conn) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [conn | args])
  end

  ## Event: [:phoenix, :endpoint, *]

  @doc false
  def phoenix_endpoint_start(_, _, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(level, fn ->
          %{method: method, request_path: request_path} = conn
          [method, ?\s, request_path]
        end)
    end
  end

  @doc false
  def phoenix_endpoint_stop(_, %{duration: duration}, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(level, fn ->
          %{status: status, state: state} = conn
          status = Integer.to_string(status)
          [connection_type(state), ?\s, status, " in ", duration(duration)]
        end)
    end
  end

  defp connection_type(:set_chunked), do: "Chunked"
  defp connection_type(_), do: "Sent"

  ## Event: [:phoenix, :error_rendered]

  @doc false
  def phoenix_error_rendered(_, _, %{log: false}, _), do: :ok

  def phoenix_error_rendered(_, _, %{log: level, status: status, kind: kind, reason: reason}, _) do
    Logger.log(level, fn ->
      [
        "Converted ",
        Atom.to_string(kind),
        ?\s,
        error_banner(kind, reason),
        " to ",
        Integer.to_string(status),
        " response"
      ]
    end)
  end

  defp error_banner(:error, %type{}), do: inspect(type)
  defp error_banner(_kind, reason), do: inspect(reason)

  ## Event: [:phoenix, :router_dispatch, :start]

  @doc false
  def phoenix_router_dispatch_start(_, _, %{log: false}, _), do: :ok

  def phoenix_router_dispatch_start(_, _, metadata, _) do
    %{log: level, conn: conn, plug: plug} = metadata
    level = log_level(level, conn)
    log_module = metadata[:log_module] || plug

    Logger.log(level, fn ->
      %{
        pipe_through: pipe_through,
        plug_opts: plug_opts
      } = metadata

      [
        "Processing with ",
        inspect(log_module),
        maybe_action(plug_opts),
        ?\n,
        "  Parameters: ",
        params(conn.params),
        ?\n,
        "  Pipelines: ",
        inspect(pipe_through)
      ]
    end)
  end

  defp maybe_action(action) when is_atom(action), do: [?., Atom.to_string(action), ?/, ?2]
  defp maybe_action(_), do: []

  defp params(%Plug.Conn.Unfetched{}), do: "[UNFETCHED]"
  defp params(params), do: params |> filter_values() |> inspect()

  ## Event: [:phoenix, :socket_connected]

  @doc false
  def phoenix_socket_connected(_, _, %{log: false}, _), do: :ok

  def phoenix_socket_connected(_, %{duration: duration}, %{log: level} = meta, _) do
    Logger.log(level, fn ->
      %{
        transport: transport,
        params: params,
        user_socket: user_socket,
        result: result,
        serializer: serializer
      } = meta

      [
        connect_result(result),
        inspect(user_socket),
        " in ",
        duration(duration),
        "\n  Transport: ",
        inspect(transport),
        "\n  Serializer: ",
        inspect(serializer),
        "\n  Parameters: ",
        inspect(filter_values(params))
      ]
    end)
  end

  defp connect_result(:ok), do: "CONNECTED TO "
  defp connect_result(:error), do: "REFUSED CONNECTION TO "

  ## Event: [:phoenix, :channel_joined]

  @doc false
  def phoenix_channel_joined(_, %{duration: duration}, %{socket: socket} = metadata, _) do
    channel_log(:log_join, socket, fn ->
      %{result: result, params: params} = metadata

      [
        join_result(result),
        socket.topic,
        " in ",
        duration(duration),
        "\n  Parameters: ",
        inspect(filter_values(params))
      ]
    end)
  end

  defp join_result(:ok), do: "JOINED "
  defp join_result(:error), do: "REFUSED JOIN "

  ## Event: [:phoenix, :channel_handle_in]

  @doc false
  def phoenix_channel_handled_in(_, %{duration: duration}, %{socket: socket} = metadata, _) do
    channel_log(:log_handle_in, socket, fn ->
      %{event: event, params: params} = metadata

      [
        "HANDLED ",
        event,
        " INCOMING ON ",
        socket.topic,
        " (",
        inspect(socket.channel),
        ") in ",
        duration(duration),
        "\n  Parameters: ",
        inspect(filter_values(params))
      ]
    end)
  end

  defp channel_log(_log_option, %{topic: "phoenix" <> _}, _fun), do: :ok

  defp channel_log(log_option, %{private: private}, fun) do
    if level = Map.get(private, log_option) do
      Logger.log(level, fun)
    end
  end
end
