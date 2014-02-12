defmodule Phoenix.Dispatcher.Client do
  alias Phoenix.Dispatcher.Server

  def start(request) do
    :gen_server.start(Server, request, [])
  end

  def dispatch(pid) do
    try do
      conn = :gen_server.call(pid, :dispatch)
      {:ok, conn}
    catch
      _error, reason -> {:error, reason}
    end
  end
end
