defmodule Phoenix.Transports.WebTransport.Handler do
  @moduledoc false
  Code.ensure_loaded?(:cowboy_webtransport)
  @behaviour :cowboy_webtransport

  require Logger

  alias Phoenix.Socket.Transport

  defstruct endpoint: nil,
            handler: nil,
            opts: [],
            socket_state: nil,
            stream_id: nil,
            buffer: <<>>,
            max_frame_size: 16_777_216,
            max_pending_bytes: 1_048_576,
            pending_frames: [],
            pending_bytes: 0,
            query_params: %{},
            path_params: %{},
            params: %{}

  def init(req, {endpoint, handler, opts}) do
    query_params = query_params(req)
    path_params = path_params(req)
    params = Map.merge(query_params, path_params)

    conn =
      req
      |> to_conn(params, path_params)
      |> Transport.code_reload(endpoint, opts)
      |> Transport.transport_log(opts[:transport_log])
      |> Transport.check_origin(handler, endpoint, opts, & &1)
      |> maybe_put_auth_token(params, opts[:auth_token])

    if conn.halted do
      {:ok, :cowboy_req.reply(conn.status || 403, req), :rejected}
    else
      keys = Keyword.get(opts, :connect_info, [])
      {peer_data?, keys} = split_peer_data_key(keys)

      connect_info =
        Transport.connect_info(conn, endpoint, keys,
          check_csrf: Keyword.get(opts, :check_csrf, false)
        )
        |> maybe_put_peer_data(req, peer_data?)

      config = %{
        endpoint: endpoint,
        transport: :webtransport,
        options: opts,
        params: params,
        connect_info: connect_info
      }

      case handler.connect(config) do
        {:ok, socket_state} ->
          state = %__MODULE__{
            endpoint: endpoint,
            handler: handler,
            opts: opts,
            socket_state: socket_state,
            max_frame_size: Keyword.get(opts, :max_frame_size, 16_777_216),
            max_pending_bytes: Keyword.get(opts, :max_pending_bytes, 1_048_576),
            query_params: query_params,
            path_params: path_params,
            params: params
          }

          {:cowboy_webtransport, req, state, %{req_filter: &__MODULE__.req_filter/1}}

        :error ->
          {:ok, :cowboy_req.reply(403, req), :rejected}

        {:error, _reason} ->
          {:ok, :cowboy_req.reply(403, req), :rejected}
      end
    end
  end

  def webtransport_init(%__MODULE__{handler: handler, socket_state: socket_state} = state) do
    case handler.init(socket_state) do
      {:ok, socket_state} ->
        {[], %{state | socket_state: socket_state}}

      _ ->
        {[{:close, 0, "socket init failed"}], state}
    end
  end

  def webtransport_handle({:stream_open, stream_id, :bidi}, %__MODULE__{stream_id: nil} = state) do
    commands = flush_pending(stream_id, state.pending_frames)
    {commands, %{state | stream_id: stream_id, pending_frames: [], pending_bytes: 0}}
  end

  def webtransport_handle({:stream_open, _stream_id, _type}, state) do
    {[], state}
  end

  def webtransport_handle({:opened_stream_id, _open_stream_ref, _stream_id}, state) do
    {[], state}
  end

  def webtransport_handle(
        {:stream_data, stream_id, _is_fin, data},
        %__MODULE__{stream_id: stream_id} = state
      ) do
    with {:ok, frames, buffer} <-
           parse_frames(<<state.buffer::binary, data::binary>>, state.max_frame_size),
         {:ok, commands, socket_state} <- process_frames(frames, state) do
      {commands, %{state | buffer: buffer, socket_state: socket_state}}
    else
      {:error, reason} ->
        {[{:close, 0, reason_to_string(reason)}], state}
    end
  end

  def webtransport_handle({:stream_data, _stream_id, _is_fin, _data}, state) do
    {[{:close, 0, "unexpected stream data"}], state}
  end

  def webtransport_handle({:datagram, _}, state) do
    {[{:close, 0, "datagram unsupported"}], state}
  end

  def webtransport_handle(:close_initiated, state) do
    {[], state}
  end

  # Cowboy handles terminal `{closed, _, _}` and `:closed_abruptly` by invoking
  # terminate directly, so they do not reach webtransport_handle/2.
  def webtransport_handle(_, state) do
    {[], state}
  end

  def webtransport_info(
        message,
        %__MODULE__{handler: handler, socket_state: socket_state} = state
      ) do
    case handler.handle_info(message, socket_state) do
      {:ok, socket_state} ->
        {[], %{state | socket_state: socket_state}}

      {:push, {opcode, payload}, socket_state} ->
        case encode_frame(opcode, payload) do
          {:ok, frame} ->
            if state.stream_id do
              {[{:send, state.stream_id, frame}], %{state | socket_state: socket_state}}
            else
              pending_bytes = state.pending_bytes + IO.iodata_length(frame)

              if pending_bytes > state.max_pending_bytes do
                {[{:close, 0, "pending frame buffer exceeded"}],
                 %{state | socket_state: socket_state}}
              else
                {[],
                 %{
                   state
                   | socket_state: socket_state,
                     pending_frames: [frame | state.pending_frames],
                     pending_bytes: pending_bytes
                 }}
              end
            end

          {:error, :binary_not_supported} ->
            Logger.warning(
              "Ignoring binary payload on WebTransport session because v1 WebTransport transport is text-only"
            )

            {[], %{state | socket_state: socket_state}}

          {:error, reason} ->
            {[{:close, 0, reason_to_string(reason)}], %{state | socket_state: socket_state}}
        end

      {:stop, reason, socket_state} ->
        {[{:close, 0, reason_to_string(reason)}], %{state | socket_state: socket_state}}
    end
  end

  def terminate(reason, req, %__MODULE__{handler: handler, socket_state: socket_state}) do
    _ = req
    handler.terminate(reason, socket_state)
  end

  def req_filter(req) do
    Map.take(req, [:method, :version, :scheme, :host, :port, :path, :qs, :peer, :headers])
  end

  defp process_frames(frames, state) do
    Enum.reduce_while(frames, {:ok, [], state.socket_state}, fn {payload, opts},
                                                                {:ok, commands, socket_state} ->
      case state.handler.handle_in({payload, opts}, socket_state) do
        {:ok, socket_state} ->
          {:cont, {:ok, commands, socket_state}}

        {:reply, _status, {opcode, reply_payload}, socket_state} ->
          case encode_frame(opcode, reply_payload) do
            {:ok, frame} ->
              {:cont, {:ok, [{:send, state.stream_id, frame} | commands], socket_state}}

            {:error, :binary_not_supported} ->
              Logger.warning(
                "Ignoring binary reply payload on WebTransport session because v1 WebTransport transport is text-only"
              )

              {:cont, {:ok, commands, socket_state}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end

        {:stop, reason, socket_state} ->
          _ = socket_state
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, commands, socket_state} -> {:ok, Enum.reverse(commands), socket_state}
      error -> error
    end
  end

  defp flush_pending(_stream_id, []), do: []

  defp flush_pending(stream_id, frames) do
    frames
    |> Enum.reverse()
    |> Enum.map(&{:send, stream_id, &1})
  end

  defp encode_frame(:text, payload) do
    size = IO.iodata_length(payload)
    {:ok, [<<0, size::32>>, payload]}
  rescue
    _ -> {:error, :invalid_payload}
  end

  defp encode_frame(:binary, _payload), do: {:error, :binary_not_supported}
  defp encode_frame(_opcode, _payload), do: {:error, :unsupported_opcode}

  defp parse_frames(data, max_frame_size), do: parse_frames(data, max_frame_size, [])

  defp parse_frames(<<>>, _max_frame_size, acc), do: {:ok, Enum.reverse(acc), <<>>}

  defp parse_frames(data, _max_frame_size, acc) when byte_size(data) < 5,
    do: {:ok, Enum.reverse(acc), data}

  defp parse_frames(<<type, len::32, rest::binary>> = data, max_frame_size, acc) do
    cond do
      type != 0 ->
        {:error, :invalid_type}

      len == 0 or len > max_frame_size ->
        {:error, :frame_too_large}

      byte_size(rest) < len ->
        {:ok, Enum.reverse(acc), data}

      true ->
        <<payload::binary-size(len), tail::binary>> = rest
        parse_frames(tail, max_frame_size, [{payload, [opcode: :text]} | acc])
    end
  end

  defp maybe_put_auth_token(conn, %{"auth_token" => token}, true) when is_binary(token) do
    Plug.Conn.put_private(conn, :phoenix_transport_auth_token, token)
  end

  defp maybe_put_auth_token(conn, _params, _auth_token?), do: conn

  defp split_peer_data_key(keys) do
    has_peer_data? = Enum.any?(keys, &(&1 == :peer_data))
    {has_peer_data?, Enum.reject(keys, &(&1 == :peer_data))}
  end

  defp maybe_put_peer_data(connect_info, _req, false), do: connect_info

  defp maybe_put_peer_data(connect_info, req, true) do
    {address, port} = Map.get(req, :peer, {{127, 0, 0, 1}, 0})
    Map.put(connect_info, :peer_data, %{address: address, port: port, ssl_cert: nil})
  end

  defp query_params(req) do
    req
    |> :cowboy_req.parse_qs()
    |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
    |> Map.put_new("vsn", "2.0.0")
  end

  defp path_params(req) do
    req
    |> :cowboy_req.bindings()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, Atom.to_string(key), to_string(value))
    end)
  end

  defp to_conn(req, params, path_params) do
    headers =
      req |> Map.get(:headers, %{}) |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)

    {remote_ip, _port} = Map.get(req, :peer, {{127, 0, 0, 1}, 0})
    request_path = req[:path] |> to_string()

    %Plug.Conn{
      host: req[:host] |> to_string(),
      method: req[:method] |> to_string(),
      owner: self(),
      path_info: String.split(request_path, "/", trim: true),
      port: req[:port],
      remote_ip: remote_ip,
      req_headers: headers,
      request_path: request_path,
      scheme: normalize_scheme(req[:scheme]),
      query_string: req[:qs] |> to_string(),
      path_params: path_params,
      params: params
    }
  end

  defp normalize_scheme(scheme) when scheme in [:http, :https], do: scheme
  defp normalize_scheme(<<"https">>), do: :https
  defp normalize_scheme(<<"http">>), do: :http
  defp normalize_scheme(scheme) when is_binary(scheme), do: String.to_atom(scheme)
  defp normalize_scheme(_), do: :https

  defp reason_to_string(reason) when is_binary(reason), do: reason
  defp reason_to_string(reason), do: inspect(reason)
end
