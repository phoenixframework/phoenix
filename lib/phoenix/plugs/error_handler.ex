defmodule Phoenix.Plugs.ErrorHandler do
  @behaviour Plug.Wrapper
  import Phoenix.Controller.Connection

  def init(opts), do: opts

  def wrap(conn, _, func) do
    try do
      func.(conn)
    catch
      :throw, {:halt, conn}      -> conn
      :throw, {:not_found, conn} -> handler_404(conn)
      kind, error                -> handle_error(conn, kind, error)
    end
  end

  defp handler_404(conn) do
    controller_module(conn).handle_not_found(conn)
  end

  defp handle_error(conn, kind, error) do
    controller_module(conn).handle_error(conn, kind, error)
  end
end
