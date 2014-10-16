defmodule Phoenix.Router.CowboyHandler do
  @moduledoc false
  @behaviour :cowboy_http_handler
  @connection Plug.Adapters.Cowboy.Conn

  def init({transport, :http}, req, {plug, opts}) when transport in [:tcp, :ssl] do
    case plug.call(@connection.conn(req, transport), opts) do
      %Plug.Conn{adapter: {@connection, req}}  = conn ->
        case conn.private[:upgrade] do
          {:websocket, handler} ->
            {:upgrade, :protocol, :cowboy_websocket, req, handler: handler, conn: conn}
          _ -> {:ok, req, nil}
        end
      other ->
        raise "Cowboy adapter expected #{inspect plug} to return Plug.Conn but got: #{inspect other}"
    end
  end

  def handle(req, nil) do
    {:ok, req, nil}
  end

  def terminate(_reason, _req, nil) do
    :ok
  end


  def websocket_init(_transport, req, opts) do
    handler = Dict.fetch! opts, :handler
    conn    = Dict.fetch! opts, :conn

    {:ok, state} = handler.ws_init(conn)
    {:ok, req, {handler, state}}
  end

  def websocket_handle({:text, text}, req, {handler, state}) do
    state = handler.ws_handle(text, state)
    {:ok, req, {handler, state}}
  end
  def websocket_handle(_other, req, {handler, state}) do
    {:ok, req, {handler, state}}
  end

  def websocket_info({:reply, text}, req, state) do
    {:reply, {:text, text}, req, state}
  end
  def websocket_info(:shutdown, req, state) do
    {:shutdown, req, state}
  end
  def websocket_info(:hibernate, req, {handler, state}) do
    :ok = handler.ws_hibernate(state)
    {:ok, req, state, :hibernate}
  end
  def websocket_info(message, req, {handler, state}) do
    state = handler.ws_info(message, state)
    {:ok, req, {handler, state}}
  end

  def websocket_terminate(reason, _req, {handler, state}) do
    :ok = handler.ws_terminate(reason, state)
    :ok
  end
end
