defmodule Phoenix.Socket.SocketController do
  # Maybe this validation could simply become part of the transport plug init/1 call
  # That would remove the need for this intermediate plug
  def init(opts) do
    {user_socket, opts} = Keyword.pop!(opts, :user_socket)
    {transport, opts} = Keyword.pop!(opts, :transport)

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

    validated_opts = maybe_validate_keys(opts, common_config ++ transport_config(transport))
    config = Phoenix.Socket.Transport.load_config(validated_opts, transport)

    {transport, {user_socket, config}}
  end

  def call(conn, {transport, opts}) do
    transport.call(conn, opts)
  end

  defp maybe_validate_keys(opts, keys) when is_list(opts), do: Keyword.validate!(opts, keys)
  defp maybe_validate_keys(other, _), do: other

  defp transport_config(Phoenix.Transports.WebSocket) do
    [
      :timeout,
      :max_frame_size,
      :fullsweep_after,
      :compress,
      :subprotocols,
      :error_handler
    ]
  end
end
