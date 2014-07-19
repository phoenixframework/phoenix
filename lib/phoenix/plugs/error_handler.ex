defmodule Phoenix.Plugs.ErrorHandler do
  @behaviour Plug.Wrapper
  alias Phoenix.Config

  def init(opts), do: opts

  def wrap(conn, [from: module], func) do
    try do
      func.(conn)
    catch
      :throw, {:halt, conn} -> conn
      _kind, error ->
        if Config.router(module, [:consider_all_requests_local]) do
          Phoenix.Controller.error_with_trace(conn, error)
        else
          Phoenix.Controller.error(conn, error)
        end
    end
  end
end
