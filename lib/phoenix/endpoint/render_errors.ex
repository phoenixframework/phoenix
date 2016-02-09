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
  #
  @moduledoc false

  @already_sent {:plug_conn, :sent}
  import Plug.Conn
  import Phoenix.Controller

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
        catch
          kind, reason ->
            Phoenix.Endpoint.RenderErrors.__catch__(conn, kind, reason, @phoenix_render_errors)
        end
      end
    end
  end

  @doc false
  def __catch__(_conn, :error, %Plug.Conn.WrapperError{} = wrapper, opts) do
    %{conn: conn, kind: kind, reason: reason, stack: stack} = wrapper
    __catch__(conn, kind, reason, stack, opts)
  end

  def __catch__(conn, kind, reason, opts) do
    __catch__(conn, kind, reason, System.stacktrace, opts)
  end

  defp __catch__(_conn, :error, %Phoenix.Router.NoRouteError{} = reason, stack, opts) do
    maybe_render(reason.conn, :error, reason, stack, opts)
  end

  defp __catch__(conn, kind, reason, stack, opts) do
    maybe_render(conn, kind, reason, stack, opts)
    :erlang.raise(kind, reason, stack)
  end

  ## Rendering

  # Made public with @doc false for testing.
  @doc false
  def render(conn, kind, reason, stack, opts) do
    conn = conn |> fetch_query_params() |> fetch_format(opts)

    reason = Exception.normalize(kind, reason, stack)
    format = get_format(conn)
    status = status(kind, reason)
    format = "#{status}.#{format}"

    conn
    |> put_layout(opts[:layout] || false)
    |> put_view(opts[:view])
    |> put_status(status)
    |> render(format, %{kind: kind, reason: reason, stack: stack})
  end

  defp maybe_render(conn, kind, reason, stack, opts) do
    receive do
      @already_sent ->
        send self(), @already_sent
        %{conn | state: :sent}
    after
      0 ->
        render conn, kind, reason, stack, opts
    end
  end

  defp fetch_format(conn, opts) do
    try do
      case get_format(conn) do
        format when is_binary(format) -> conn
        _ -> conn |> accepts(Keyword.fetch!(opts, :accepts))
      end
    rescue
      Phoenix.NotAcceptableError ->
        put_format(conn, Keyword.fetch!(opts, :accepts) |> List.first())
    end
  end

  defp status(:error, error), do: Plug.Exception.status(error)
  defp status(:throw, _throw), do: 500
  defp status(:exit, _exit),   do: 500
end
