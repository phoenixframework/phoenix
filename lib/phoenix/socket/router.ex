defmodule Phoenix.Socket.Router do
  @moduledoc false

  defmacro socket(path, user_socket, opts) do
    websocket = Keyword.get(opts, :websocket, true)
    longpoll = Keyword.get(opts, :longpoll, true)

    ws_quote =
      if websocket do
        websocket = put_auth_token(websocket, opts[:auth_token])

        end_segment =
          case websocket do
            true -> "/websocket"
            list -> Keyword.get(list, :path, "/websocket")
          end

        path = Path.join(path, end_segment)

        quote do
          match :*,
                unquote(path),
                Phoenix.Socket.SocketController,
                [
                  {:transport, Phoenix.Transports.WebSocket},
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

        end_segment =
          case longpoll do
            true -> "/longpoll"
            list -> Keyword.get(list, :path, "/longpoll")
          end

        path = Path.join(path, end_segment)

        quote do
          match :*,
                unquote(path),
                Phoenix.Socket.SocketController,
                [
                  {:transport, Phoenix.Transports.LongPoll},
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
