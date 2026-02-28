defmodule Phoenix.Transports.WebTransport do
  @moduledoc false

  alias Phoenix.Socket.V2

  @supported_connect_info_keys [
    :peer_data,
    :trace_context_headers,
    :x_headers,
    :uri,
    :user_agent,
    :auth_token
  ]

  def default_config() do
    [
      path: "/webtransport",
      serializer: [{V2.JSONSerializer, "~> 2.0.0"}],
      transport_log: false,
      check_csrf: false,
      max_frame_size: 16_777_216,
      max_pending_bytes: 1_048_576
    ]
  end

  def validate_config!(config) do
    connect_info_keys = Keyword.get(config, :connect_info, [])

    if Keyword.get(config, :path) != "/webtransport" do
      raise ArgumentError, "custom webtransport :path is not supported in v1"
    end

    validate_connect_info_keys!(connect_info_keys)
    validate_check_csrf!(config, connect_info_keys)
    validate_serializers!(Keyword.fetch!(config, :serializer))
    config
  end

  defp validate_serializers!(serializers) when is_list(serializers) do
    valid? =
      Enum.all?(serializers, fn
        {V2.JSONSerializer, _} -> true
        _ -> false
      end)

    if valid? do
      :ok
    else
      raise ArgumentError, "webtransport requires V2.JSONSerializer-only configuration in v1"
    end
  end

  defp validate_connect_info_keys!(keys) do
    Enum.each(keys, fn
      :sec_websocket_headers ->
        raise ArgumentError,
              ":sec_websocket_headers connect_info is not supported for webtransport"

      key when key in @supported_connect_info_keys ->
        :ok

      {_, _} ->
        :ok

      key ->
        raise ArgumentError,
              "unsupported webtransport connect_info key: #{inspect(key)}. Supported keys: #{inspect(@supported_connect_info_keys)}"
    end)
  end

  defp validate_check_csrf!(config, connect_info_keys) do
    if Keyword.get(config, :check_csrf, false) and
         not Enum.any?(connect_info_keys, &match?({:session, _}, &1)) do
      raise ArgumentError,
            "webtransport with check_csrf: true requires connect_info to include {:session, ...}"
    end
  end
end
