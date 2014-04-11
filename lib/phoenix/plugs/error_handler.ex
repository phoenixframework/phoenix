defmodule Phoenix.Plugs.ErrorHandler do
  @behaviour Plug.Wrapper
  alias Phoenix.Config

  def init(opts), do: opts

  def wrap(conn, [from: module], func) do
    try do
      func.(conn)
    catch
      _kind, error ->
        if Config.for(module).router[:consider_all_requests_local] do
          Phoenix.Controller.error_with_trace(conn, error)
        else
          Phoenix.Controller.error(conn, error)
        end
    end
  end
end
