defmodule Phoenix.Socket.Router do
  @moduledoc false

  defmacro socket(path, user_socket, opts) do
    common_config = [
      :path,
      :serializer,
      :transport_log,
      :check_origin,
      :check_csrf,
      :code_reloader,
      :connect_info,
      :auth_token
    ]

    websocket =
      opts
      |> Keyword.get(:websocket, true)
      |> maybe_validate_keys(
        common_config ++
          [
            :timeout,
            :max_frame_size,
            :fullsweep_after,
            :compress,
            :subprotocols,
            :error_handler
          ]
      )

    longpoll =
      opts
      |> Keyword.get(:longpoll, true)
      |> maybe_validate_keys(
        common_config ++
          [
            :window_ms,
            :pubsub_timeout_ms,
            :crypto
          ]
      )

    ws_quote =
      if websocket do
        websocket = put_auth_token(websocket, opts[:auth_token])
        config = Phoenix.Socket.Transport.load_config(websocket, Phoenix.Transports.WebSocket)
        end_path_fragment = Keyword.fetch!(config, :path)
        path = Path.join(path, end_path_fragment)

        quote do
          match :*,
                unquote(path),
                Phoenix.Transports.WebSocket,
                {unquote(user_socket), unquote(Macro.escape(config))}
        end
      else
        []
      end

    lp_quote =
      if longpoll do
        longpoll = put_auth_token(longpoll, opts[:auth_token])
        config = Phoenix.Socket.Transport.load_config(longpoll, Phoenix.Transports.LongPoll)
        end_path_fragment = Keyword.fetch!(config, :path)
        path = Path.join(path, end_path_fragment)

        quote do
          match :*,
                unquote(path),
                Phoenix.Transports.LongPoll,
                {unquote(user_socket), unquote(Macro.escape(config))}
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

  defp maybe_validate_keys(opts, keys) when is_list(opts), do: Keyword.validate!(opts, keys)
  defp maybe_validate_keys(other, _), do: other
end
