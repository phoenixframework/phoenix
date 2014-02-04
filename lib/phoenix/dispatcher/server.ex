defmodule Phoenix.Dispatcher.Server do
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
  def terminate(_reason, _request) do
  end
end

