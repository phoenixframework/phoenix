defmodule Phoenix.Endpoint.Cowboy2Adapter do
  @moduledoc """
  The Cowboy2 adapter for Phoenix.

  It implements the required `child_spec/3` function as well
  as WebSocket transport functionality.

  ## Custom dispatch options

  You can provide custom dispatch options in order to use Phoenix's
  builtin Cowboy server with custom handlers. For example, to handle
  raw WebSockets [as shown in Cowboy's docs](https://github.com/ninenines/cowboy/tree/2.0.x/examples)).

  The options are passed to both `:http` and `:https` keys in the
  endpoint configuration. However, once you pass your custom dispatch
  options, you will need to manually wire all Phoenix endpoints,
  including the socket transports.

  You will need the following rules:

    * Per websocket transport:

      ```
      {"/socket/websocket", Phoenix.Endpoint.Cowboy2WebSocket,
        {Phoenix.Transports.WebSocket,
          {MyAppWeb.Endpoint, MyAppWeb.UserSocket, websocket_config}}}
      ```

    * Per longpoll transport:

      ```
      {"/socket/long_poll", Plug.Adapters.Cowboy2.Handler,
        {Phoenix.Transports.LongPoll,
          {MyAppWeb.Endpoint, MyAppWeb.UserSocket, longpoll_config}}}
      ```

    * For the live-reload websocket:

      ```
      {"/phoenix/live_reload/socket/websocket", Phoenix.Endpoint.Cowboy2WebSocket,
        {Phoenix.Transports.WebSocket,
          {MyAppWeb.Endpoint, Phoenix.LiveReloader.Socket, websocket_config}}}
      ```

      If you decide to include the live-reload websocket, you should
      disable it when building for production.

    * For the endpoint:

      ```
      {:_, Plug.Adapters.Cowboy2.Handler, {MyAppWeb.Endpoint, []}}
      ```

  For example:

      config :myapp, MyAppWeb.Endpoint,
        http: [dispatch: [
                {:_, [
                    {"/foo", MyAppWeb.CustomHandler, []},
                    {"/bar", MyAppWeb.AnotherHandler, []},
                    {"/phoenix/live_reload/socket/websocket", Phoenix.Endpoint.Cowboy2WebSocket,
                      {Phoenix.Transports.WebSocket,
                        {MyAppWeb.Endpoint, Phoenix.LiveReloader.Socket, websocket_config}}},
                    {:_, Plug.Adapters.Cowboy2.Handler, {MyAppWeb.Endpoint, []}}
                  ]}]]

  Note: if you reconfigure HTTP options in `MyAppWeb.Endpoint.init/1`,
  your dispatch options set in mix config will be overwritten.

  It is also important to specify your handlers first, otherwise
  Phoenix will intercept the requests before they get to your handler.
  """

  require Logger

  @doc false
  def child_spec(scheme, endpoint, config) do
    if scheme == :https do
      Application.ensure_all_started(:ssl)
    end

    # TODO: Get rid of this.
    dispatches =
      for {path, socket, socket_opts} <- endpoint.__sockets__,
          {key, config} <- Keyword.take(socket_opts, [:websocket, :longpoll]),
          do: {Path.join(path, Atom.to_string(key)),
               handler_for_transport(key),
               {module_for_transport(key), {endpoint, socket, config}}}

    dispatches =
      dispatches ++ [{:_, Plug.Adapters.Cowboy2.Handler, {endpoint, []}}]

    config = Keyword.put_new(config, :dispatch, [{:_, dispatches}])
    spec = Plug.Adapters.Cowboy2.child_spec(scheme: scheme, plug: {endpoint, []}, options: config)
    update_in spec.start, &{__MODULE__, :start_link, [scheme, endpoint, &1]}
  end

  defp handler_for_transport(:longpoll), do: Plug.Adapters.Cowboy2.Handler
  defp handler_for_transport(:websocket), do: Phoenix.Endpoint.Cowboy2WebSocket

  defp module_for_transport(:longpoll), do: Phoenix.Transports.LongPoll
  defp module_for_transport(:websocket), do: Phoenix.Transports.WebSocket

  @doc false
  def start_link(scheme, endpoint, {m, f, [ref | _] = a}) do
    # ref is used by Ranch to identify its listeners, defaulting
    # to plug.HTTP and plug.HTTPS and overridable by users.
    case apply(m, f, a) do
      {:ok, pid} ->
        Logger.info info(scheme, endpoint, ref)
        {:ok, pid}

      {:error, {:shutdown, {_, _, {{_, {:error, :eaddrinuse}}, _}}}} = error ->
        Logger.error [info(scheme, endpoint, ref), " failed, port already in use"]
        error

      {:error, _} = error ->
        error
    end
  end

  defp info(scheme, endpoint, ref) do
    {addr, port} = :ranch.get_addr(ref)
    addr_str = :inet.ntoa(addr)
    "Running #{inspect endpoint} with Cowboy2 using #{scheme}://#{addr_str}:#{port}"
  end
end
