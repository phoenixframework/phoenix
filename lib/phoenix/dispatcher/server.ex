defmodule Phoenix.Dispatcher.Server do
  alias Phoenix.Router

  def init({sender, request}) do
    {:ok, {sender, request}}
  end

  def handle_cast(:dispatch, {sender, req}) do
    plug = apply(req.router, :match, [req.conn, req.http_method, req.path])
    send sender, plug
    {:stop, :normal, {sender, req}}
  end

  def terminate(:normal, _state) do
    IO.puts "Done!"
  end
  def terminate(reason, {sender, request}) do
    IO.puts ">> TERM"
    send sender, {:error, request.conn, reason}
  end
end

