defmodule Phoenix.Plugs.ErrorHandler do
  @behaviour Plug.Wrapper
  alias Phoenix.Config
  alias Phoenix.Controller
  require Logger

  def init(opts), do: opts

  def wrap(conn, [from: module], func) do
    try do
      func.(conn)
    catch
      :throw, {:halt, conn} -> conn
      kind, error ->
        Logger.error(Exception.format(kind, error))
        if Config.router(module, [:consider_all_requests_local]) do
          Controller.Action.error_with_trace(conn, error)
        else
          Controller.Action.error(conn, error)
        end
    end
  end
end
