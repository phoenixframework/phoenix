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
  options, you will need to manually wire the Phoenix endpoint by
  adding the following rule:

      {:_, Phoenix.Endpoint.Cowboy2Handler, {MyAppWeb.Endpoint, []}}

  For example:

      config :myapp, MyAppWeb.Endpoint,
        http: [dispatch: [
                {:_, [
                    {"/foo", MyAppWeb.CustomHandler, []},
                    {:_, Phoenix.Endpoint.Cowboy2Handler, {MyAppWeb.Endpoint, []}}
                  ]}]]

  It is also important to specify your handlers first, otherwise
  Phoenix will intercept the requests before they get to your handler.
  """

  require Logger

  @doc false
  def child_spec(scheme, endpoint, config) do
    if scheme == :https do
      Application.ensure_all_started(:ssl)
    end

    dispatches = [{:_, Phoenix.Endpoint.Cowboy2Handler, {endpoint, endpoint.init([])}}]
    config = Keyword.put_new(config, :dispatch, [{:_, dispatches}])
    spec = Plug.Cowboy.child_spec(scheme: scheme, plug: {endpoint, []}, options: config)
    update_in spec.start, &{__MODULE__, :start_link, [scheme, endpoint, &1]}
  end

  @doc false
  def start_link(scheme, endpoint, {m, f, [ref | _] = a}) do
    # ref is used by Ranch to identify its listeners, defaulting
    # to plug.HTTP and plug.HTTPS and overridable by users.
    case apply(m, f, a) do
      {:ok, pid} ->
        Logger.info(fn -> info(scheme, endpoint, ref) end)
        {:ok, pid}

      {:error, {:shutdown, {_, _, {{_, {:error, :eaddrinuse}}, _}}}} = error ->
        Logger.error [info(scheme, endpoint, ref), " failed, port already in use"]
        error

      {:error, _} = error ->
        error
    end
  end

  @doc false
  def info(scheme, endpoint, ref) do
    server = "cowboy #{Application.spec(:cowboy)[:vsn]}"
    "Running #{inspect endpoint} with #{server} at #{uri(scheme, endpoint, ref)}"
  end

  defp uri(scheme, endpoint, ref) do
    case :ranch.get_addr(ref) do
      {:local, unix_path} ->
        %URI{host: URI.encode_www_form(unix_path), scheme: "#{scheme}+unix"}

      _ ->
        endpoint.struct_url()
    end
  end
end
