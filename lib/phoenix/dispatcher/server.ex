defmodule Phoenix.Dispatcher.Server do
  alias Phoenix.Router
  use GenServer.Behaviour

  def init(request) do
    {:ok, request}
  end

  def handle_call(:dispatch, _from, req) do
    plug = apply(req.router, :match, [req.conn, req.http_method, req.path])
    {:stop, :normal, plug, req}
  end

  def terminate(:normal, _request) do
  end
  def terminate(reason, _request) do
  end
end

