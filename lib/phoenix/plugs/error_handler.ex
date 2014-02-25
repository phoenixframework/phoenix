defmodule Phoenix.Plugs.ErrorHandler do
  @behaviour Plug.Wrapper

  import Plug.Connection
  import Phoenix.Controller

  def init(opts), do: opts

  def wrap(conn, _opts, fun) do
    try do
      fun.(conn)
    catch
      kind, error ->
        stacktrace = System.stacktrace
        exception = Exception.normalize(error)
        status = Plug.Exception.status(error)
        html conn, status, """
          <html>
            <h2>(#{inspect exception.__record__(:name)}) #{exception.message}</h2>
            <h4>Stacktrace</h4>
            <pre>#{Exception.format_stacktrace stacktrace}</pre>
          </html>
        """
    end
  end
end
