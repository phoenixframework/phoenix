defmodule Phoenix.Socket.Router do
  @moduledoc false

  defmacro socket(path, user_socket, opts) do
    websocket = Keyword.get(opts, :websocket, true)
    longpoll = Keyword.get(opts, :longpoll, true)

    ws_quote =
      if websocket do
        websocket = put_auth_token(websocket, opts[:auth_token])
        {end_segment, websocket} = Keyword.pop(websocket, :path, "/websocket")
        path = Path.join(path, end_segment)

        quote do
          match :*,
                unquote(path),
                Phoenix.Transports.WebSocket,
                [
                  {:user_socket, unquote(user_socket)}
                  | unquote(websocket)
                ]
        end
      else
        []
      end

    lp_quote =
      if longpoll do
        longpoll = put_auth_token(longpoll, opts[:auth_token])
        {end_segment, longpoll} = Keyword.pop(longpoll, :path, "/longpoll")
        path = Path.join(path, end_segment)

        quote do
          match :*,
                unquote(path),
                Phoenix.Transports.LongPoll,
                [
                  {:user_socket, unquote(user_socket)}
                  | unquote(longpoll)
                ]
        end
      else
        []
      end

    quote do
      unquote(ws_quote)
      unquote(lp_quote)
    end
  end

  defp put_auth_token(true, enabled), do: [auth_token: enabled]
  defp put_auth_token(opts, enabled), do: Keyword.put(opts, :auth_token, enabled)
end
