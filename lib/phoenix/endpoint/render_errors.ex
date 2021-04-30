defmodule Phoenix.Endpoint.RenderErrors do
  # This module is used to catch failures and render them using a view.
  #
  # This module is automatically used in `Phoenix.Endpoint` where it
  # overrides `call/2` to provide rendering. Once the error is
  # rendered, the error is reraised unless it is a NoRouteError.
  #
  # ## Options
  #
  #   * `:view` - the name of the view we render templates against
  #   * `:format` - the format to use when none is available from the request
  #   * `:accepts` - list of accepted formats errors will be rendered for
  #   * `:log` - the `t:Logger.level/0` or `false` to disable logging rendered errors
  #
  @moduledoc false

  import Plug.Conn

  require Phoenix.Endpoint
  require Logger

  alias Phoenix.Router.NoRouteError
  alias Phoenix.Controller

  @already_sent {:plug_conn, :sent}

  @doc false
  defmacro __using__(opts) do
    quote do
      @before_compile Phoenix.Endpoint.RenderErrors
      @phoenix_render_errors unquote(opts)
    end
  end

  @doc false
  defmacro __before_compile__(_) do
    quote location: :keep do
      defoverridable [call: 2]

      def call(conn, opts) do
        try do
          super(conn, opts)
        rescue
          e in Plug.Conn.WrapperError ->
            %{conn: conn, kind: kind, reason: reason, stack: stack} = e
            unquote(__MODULE__).__catch__(conn, kind, reason, stack, @phoenix_render_errors)
        catch
          kind, reason ->
            stack = __STACKTRACE__
            unquote(__MODULE__).__catch__(conn, kind, reason, stack, @phoenix_render_errors)
        end
      end
    end
  end

  @doc false
  def __catch__(conn, kind, reason, stack, opts) do
    receive do
      @already_sent ->
        send(self(), @already_sent)
        %Plug.Conn{conn | state: :sent}

      after 0 ->
        instrument_render_and_send(conn, kind, reason, stack, opts)
    end

    :erlang.raise(kind, reason, stack)
  end

  defp instrument_render_and_send(conn, kind, reason, stack, opts) do
    level = Keyword.get(opts, :log, :debug)
    status = status(kind, reason)
    conn = error_conn(conn, kind, reason)
    start = System.monotonic_time()
    metadata = %{conn: conn, status: status, kind: kind, reason: reason, stacktrace: stack, log: level}

    try do
      render(conn, status, kind, reason, stack, opts)
    after
      duration = System.monotonic_time() - start
      :telemetry.execute([:phoenix, :error_rendered], %{duration: duration}, metadata)
    end
  end

  defp error_conn(_conn, :error, %NoRouteError{conn: conn}), do: conn
  defp error_conn(conn, _kind, _reason), do: conn

  ## Rendering

  @doc false
  def __debugger_banner__(_conn, _status, _kind, %NoRouteError{router: router}, _stack) do
    """
    <h3>Available routes</h3>
    <pre>#{Phoenix.Router.ConsoleFormatter.format(router)}</pre>
    """
  end
  def __debugger_banner__(_conn, _status, _kind, _reason, _stack), do: nil

  defp render(conn, status, kind, reason, stack, opts) do
    view = Keyword.fetch!(opts, :view)
    conn =
      conn
      |> maybe_fetch_query_params()
      |> maybe_fetch_format(opts)
      |> Plug.Conn.put_status(status)
      |> Controller.put_root_layout(opts[:root_layout] || false)
      |> Controller.put_layout(opts[:layout] || false)
      |> Controller.put_view(view)

    reason = Exception.normalize(kind, reason, stack)
    format = Controller.get_format(conn)
    template = "#{conn.status}.#{format}"
    assigns = %{kind: kind, reason: reason, stack: stack, status: conn.status}

    conn
    |> Controller.put_view(view)
    |> Controller.render(template, assigns)
  end

  defp maybe_fetch_query_params(conn) do
    fetch_query_params(conn)
  rescue
    Plug.Conn.InvalidQueryError ->
      case conn.params do
        %Plug.Conn.Unfetched{} -> %Plug.Conn{conn | query_params: %{}, params: %{}}
        params -> %Plug.Conn{conn | query_params: %{}, params: params}
      end
  end

  defp maybe_fetch_format(conn, opts) do
    # We ignore params["_format"] although we respect any already stored.
    case conn.private do
      %{phoenix_format: format} when is_binary(format) -> conn
      _ -> Controller.accepts(conn, Keyword.fetch!(opts, :accepts))
    end
  rescue
    e in Phoenix.NotAcceptableError ->
      fallback_format = Keyword.fetch!(opts, :accepts) |> List.first()
      Logger.debug("Could not render errors due to #{Exception.message(e)}. " <>
                   "Errors will be rendered using the first accepted format #{inspect fallback_format} as fallback. " <>
                   "Please customize the :accepts option under the :render_errors configuration " <>
                   "in your endpoint if you want to support other formats or choose another fallback")
      Controller.put_format(conn, fallback_format)
  end

  defp status(:error, error), do: Plug.Exception.status(error)
  defp status(:throw, _throw), do: 500
  defp status(:exit, _exit),   do: 500
end
