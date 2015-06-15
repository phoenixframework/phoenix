defmodule Phoenix.Endpoint.CowboyHandler do
  @moduledoc false
  require Logger

  ## Phoenix API

  @doc """
  Starts the cowboy adapter

  ## Custom dispatch options

  *Disclaimer*: This feature depends on the internals of cowboy 1.x API, which
  might change in the future when cowboy 2.x is released.

  You can provide custom dispatch options in order to use Phoenix's builtin
  cowboy server with custom handler(s), ie, to handle raw WebSockets
  [as shown in cowboy's docs](https://github.com/ninenines/cowboy/tree/1.0.x/examples)).

  The options are passed to both `:http` and `:https` keys in the endpoint
  configuration. In order to preserve the default dispatch of Phoenix's router
  you need to specify it explicitly when providing the `:dispatch` option, for
  example:

      config :myapp, MyApp.Endpoint,
        http: [dispatch: [
                {:_, [
                    {"/foo", MyApp.CustomHandler, []},
                    {"/bar", MyApp.AnotherHandler, []},
                    {:_, Phoenix.Endpoint.CowboyHandler, {MyApp.Endpoint, []}}
                  ]}]]

  It is also important to specify your handlers first, otherwise Phoenix will
  intercept the requests before they get to your handler
  """
  def start_link(scheme, endpoint, config, {m, f, a}) do
    case apply(m, f, a) do
      {:ok, pid} ->
        Logger.info info(scheme, endpoint, config)
        {:ok, pid}

      {:error, {:shutdown, {_, _, {{_, {:error, :eaddrinuse}}, _}}}} = error ->
        Logger.error [info(scheme, endpoint, config), " failed, port already in use"]
        error

      {:error, _} = error ->
        error
    end
  end

  defp info(scheme, endpoint, config) do
    "Running #{inspect endpoint} with Cowboy on port #{inspect config[:port]} (#{scheme})"
  end

  def child_spec(scheme, endpoint, config) do
    # Use put_new to allow custom dispatches
    config =
      config
      |> Keyword.put_new(:dispatch, [{:_, [{:_, __MODULE__, {endpoint, []}}]}])

    {ref, mfa, type, timeout, kind, modules} =
      Plug.Adapters.Cowboy.child_spec(scheme, endpoint, [], config)

    mfa = {__MODULE__, :start_link, [scheme, endpoint, config, mfa]}
    {ref, mfa, type, timeout, kind, modules}
  end

  ## Cowboy Handler

  @connection Plug.Adapters.Cowboy.Conn
  @websockets Phoenix.Endpoint.CowboyWebsocket
  @already_sent {:plug_conn, :sent}

  def init({transport, :http}, req, {plug, opts}) when transport in [:tcp, :ssl] do
    {:upgrade, :protocol, __MODULE__, req, {transport, plug, opts}}
  end

  def upgrade(req, env, __MODULE__, {transport, plug, opts}) do
    conn = @connection.conn(req, transport)
    try do
      case plug.call(conn, opts) do
        %Plug.Conn{private: %{phoenix_upgrade: upgrade}} = conn ->
          {@connection, req}    = conn.adapter
          {:websocket, handler} = upgrade
          args = [req, env, @websockets, {handler, conn}]
          {:upgrade, @websockets, conn, args}
        conn ->
          {@connection, req} = maybe_send(conn, plug).adapter
          {:ok, req, [{:result, :ok} | env]}
      end
    else
      {:upgrade, module, conn, args} ->
        module.call(conn, args)
      {:ok, _req, _env} = ok ->
        ok
    catch
      :error, value ->
        stack = System.stacktrace()
        exception = Exception.normalize(:error, value, stack)
        reason = {{exception, stack}, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
      :throw, value ->
        stack = System.stacktrace()
        reason = {{{:nocatch, value}, stack}, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
      :exit, value ->
        stack = System.stacktrace()
        reason = {value, {plug, :call, [conn, opts]}}
        terminate(reason, req, stack)
    after
      receive do
        @already_sent -> :ok
      after
        0 -> :ok
      end
    end
  end

  def terminate(reason, req, stack) do
    :cowboy_req.maybe_reply(stack, req)
    exit(reason)
  end

  defp maybe_send(%Plug.Conn{state: :unset}, _plug),      do: raise Plug.Conn.NotSentError
  defp maybe_send(%Plug.Conn{state: :set} = conn, _plug), do: Plug.Conn.send_resp(conn)
  defp maybe_send(%Plug.Conn{} = conn, _plug),            do: conn
  defp maybe_send(other, plug) do
    raise "Cowboy adapter expected #{inspect plug} to return Plug.Conn but got: #{inspect other}"
  end

end
