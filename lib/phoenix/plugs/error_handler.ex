defmodule Phoenix.Plugs.ErrorHandler do
  @behaviour Plug.Wrapper

  def init(opts), do: opts

  def wrap(conn, _opts, func) do
    try do
      func.(conn)
    catch
      _kind, error -> Phoenix.Controller.error(conn, error)
    end
  end
end
