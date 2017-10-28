defmodule Phoenix.Endpoint.Cowboy2Handler do
  @moduledoc """
  The Cowboy2 adapter for Phoenix.

  It implements the required `child_spec/3` function as well
  as the handler for the WebSocket transport.

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

          {"/socket/websocket", Phoenix.Endpoint.Cowboy2WebSocket,
            {Phoenix.Transports.WebSocket,
              {MyApp.Endpoint, MyApp.UserSocket, :websocket}}}

    * Per longpoll transport:

          {"/socket/long_poll", Plug.Adapters.Cowboy2.Handler,
            {Phoenix.Transports.LongPoll,
              {MyApp.Endpoint, MyApp.UserSocket, :longpoll}}}

    * For the endpoint:

          {:_, Plug.Adapters.Cowboy2.Handler, {MyApp.Endpoint, []}}

  For example:

      config :myapp, MyApp.Endpoint,
        http: [dispatch: [
                {:_, [
                    {"/foo", MyApp.CustomHandler, []},
                    {"/bar", MyApp.AnotherHandler, []},
                    {:_, Plug.Adapters.Cowboy2.Handler, {MyApp.Endpoint, []}}
                  ]}]]

  It is also important to specify your handlers first, otherwise
  Phoenix will intercept the requests before they get to your handler.
  """
  @behaviour Phoenix.Endpoint.Handler
  require Logger

  @doc """
  Generates a childspec to be used in the supervision tree.
  """
  def child_spec(scheme, endpoint, config) do
    if scheme == :https do
      Application.ensure_all_started(:ssl)
    end

    dispatches =
      for {path, socket} <- endpoint.__sockets__,
          {transport, {module, config}} <- socket.__transports__,
          # Allow handlers to be configured at the transport level
          handler = config[:cowboy] || default_for(module),
          do: {Path.join(path, Atom.to_string(transport)),
               handler,
               {module, {endpoint, socket, transport}}}

    dispatches =
      dispatches ++ [{:_, Plug.Adapters.Cowboy2.Handler, {endpoint, []}}]

    # Use put_new to allow custom dispatches
    config = Keyword.put_new(config, :dispatch, [{:_, dispatches}])

    {ref, mfa, type, timeout, kind, modules} =
      Plug.Adapters.Cowboy2.child_spec(scheme, endpoint, [], config)

    # Rewrite MFA for proper error reporting
    mfa = {__MODULE__, :start_link, [scheme, endpoint, mfa]}
    {ref, mfa, type, timeout, kind, modules}
  end

  defp default_for(Phoenix.Transports.LongPoll), do: Plug.Adapters.Cowboy2.Handler
  defp default_for(Phoenix.Transports.WebSocket), do: Phoenix.Endpoint.Cowboy2WebSocket
  defp default_for(_), do: nil

  @doc """
  Callback to start the Cowboy2 endpoint.
  """
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
