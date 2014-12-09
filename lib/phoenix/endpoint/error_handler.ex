defmodule Phoenix.Endpoint.ErrorHandler do
  # This module is used to catch failures and render them using a view.
  #
  # This module is automatically used in `Phoenix.Router` where it
  # overrides `call/2` to provide rendering. Once the error is
  # rendered, the error is reraised unless it is a NoRouteError.
  @moduledoc false

  @already_sent {:plug_conn, :sent}
  import Plug.Conn
  import Phoenix.Controller

  @doc false
  defmacro __using__(opts) do
    quote do
      @before_compile Phoenix.Endpoint.ErrorHandler
      @phoenix_render_errors unquote(opts)
    end
  end

  @doc false
  defmacro __before_compile__(_) do
    quote location: :keep do
      defoverridable [call: 2]

      def call(conn, opts) do
        Phoenix.Endpoint.ErrorHandler.wrap(conn, @phoenix_render_errors, fn -> super(conn, opts) end)
      end
    end
  end

  @doc """
  Wraps a given function and renders a nice error page
  using the given view.

  ## Options

    * `:view` - the name of the view we render templates against

  """
  def wrap(conn, opts, fun) do
    try do
      fun.()
    rescue
      # Today we special case no NoRouteError because we don't
      # want to see it logged. In the future, the requirements
      # may also change when it comes to cascading routers.
      e in [Phoenix.Router.NoRouteError] ->
        maybe_render(e.conn, :error, e, System.stacktrace, opts)

    catch
      kind, reason ->
        stack = System.stacktrace
        maybe_render(conn, kind, reason, stack, opts)
        :erlang.raise(kind, reason, stack)
    end
  end

  # Made public with @doc false for testing.
  @doc false
  def render(conn, kind, reason, stack, opts) do
    reason = Exception.normalize(kind, reason, stack)
    format = format(conn)
    status = status(kind, reason)
    format = "#{status}.#{format}"

    conn
    |> put_layout(false)
    |> put_view(opts[:view])
    |> put_status(status)
    |> render(format, %{kind: kind, reason: reason, stack: stack})
  end

  defp maybe_render(conn, kind, reason, stack, opts) do
    receive do
      @already_sent ->
        send self(), @already_sent
        conn
    after
      0 ->
        render conn, kind, reason, stack, opts
    end
  end

  defp format(conn) do
    case conn.params do
      %{"format" => format} -> format
      _ -> "html"
    end
  end

  defp status(:error, error), do: Plug.Exception.status(error)
  defp status(:throw, _throw), do: 500
  defp status(:exit, _exit),   do: 500
end
