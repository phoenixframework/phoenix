defmodule Phoenix.Transports.LongPoll do
  @moduledoc false
  @behaviour Plug

  # The maximum is 10MB but read_body will cap the whole request at ~8MB,
  # so this acts as a secondary protection mechanism.
  @max_base64_size 10_000_000
  @max_poll_batch_size 100
  @connect_info_opts [:check_csrf]
  @token_header "x-phoenix-longpoll-token"

  import Plug.Conn
  alias Phoenix.Socket.{V1, V2, Transport}

  def default_config() do
    [
      window_ms: 10_000,
      path: "/longpoll",
      pubsub_timeout_ms: 2_000,
      serializer: [{V1.JSONSerializer, "~> 1.0.0"}, {V2.JSONSerializer, "~> 2.0.0"}],
      transport_log: false,
      crypto: [max_age: 1_209_600]
    ]
  end

  def init(opts), do: opts

  def call(conn, {endpoint, handler, opts}) do
    conn
    |> fetch_query_params()
    |> put_resp_header("access-control-allow-origin", "*")
    |> Transport.code_reload(endpoint, opts)
    |> Transport.transport_log(opts[:transport_log])
    |> Transport.check_origin(handler, endpoint, opts, &status_json/1)
    |> dispatch(endpoint, handler, opts)
  end

  defp dispatch(%{halted: true} = conn, _, _, _) do
    conn
  end

  # Responds to pre-flight CORS requests with Allow-Origin-* headers.
  # We allow cross-origin requests as we always validate the Origin header.
  defp dispatch(%{method: "OPTIONS"} = conn, _, _, _) do
    headers = get_req_header(conn, "access-control-request-headers") |> Enum.join(", ")

    conn
    |> put_resp_header("access-control-allow-headers", headers)
    |> put_resp_header("access-control-allow-methods", "get, post, options")
    |> put_resp_header("access-control-max-age", "3600")
    |> send_resp(:ok, "")
  end

  # Starts a new session or listen to a message if one already exists.
  defp dispatch(%{method: "GET"} = conn, endpoint, handler, opts) do
    case resume_session(conn, endpoint, opts) do
      {:ok, new_conn, server_ref, token} ->
        listen(new_conn, server_ref, token, endpoint, opts)

      :error ->
        new_session(conn, endpoint, handler, opts)
    end
  end

  # Publish the message.
  defp dispatch(%{method: "POST"} = conn, endpoint, _, opts) do
    case resume_session(conn, endpoint, opts) do
      {:ok, new_conn, server_ref, _token} ->
        publish(new_conn, server_ref, endpoint, opts)

      :error ->
        conn |> put_status(:gone) |> status_json()
    end
  end

  # All other requests should fail.
  defp dispatch(conn, _, _, _) do
    send_resp(conn, :bad_request, "")
  end

  defp publish(conn, server_ref, endpoint, opts) do
    case read_body(conn, []) do
      {:ok, body, conn} ->
        # We need to match on both v1 and v2 protocol, as well as wrap for backwards compat
        {status, seq} =
          case get_req_header(conn, "content-type") do
            ["application/x-ndjson"] ->
              # the seq of the first message, sent by clients that resend messages
              #
              # TODO: Require seq in Phoenix 1.10. Phoenix 1.8 clients don't send it.
              # Phoenix 1.9 clients only omit it after their session reached a 1.8 node.
              seq = int_param(conn, "seq")

              status =
                body
                |> String.splitter(["\n", "\r\n"])
                |> Stream.take(@max_poll_batch_size)
                |> Stream.with_index()
                |> Enum.find_value(fn {part, index} ->
                  msg =
                    case part do
                      "[" <> _ = txt -> {txt, :text}
                      base64 -> {safe_decode64!(base64), :binary}
                    end

                  transport_dispatch(endpoint, server_ref, msg, seq && seq + index, opts)
                end)

              {status, seq}

            _ ->
              {transport_dispatch(endpoint, server_ref, {body, :text}, nil, opts), nil}
          end

        # the seq tells clients that we drop the messages they send again
        extra = if seq, do: %{"seq" => seq}, else: %{}
        conn |> put_status(status || :ok) |> status_json(extra)

      _ ->
        raise Plug.BadRequestError
    end
  end

  defp safe_decode64!(base64) do
    if byte_size(base64) <= @max_base64_size do
      Base.decode64!(base64)
    else
      raise Plug.BadRequestError
    end
  end

  defp transport_dispatch(endpoint, server_ref, body, seq, opts) do
    ref = make_ref()

    # TODO: Always send seq in Phoenix 1.10, see publish/4
    message =
      if seq,
        do: {:dispatch, client_ref(server_ref), body, ref, seq},
        else: {:dispatch, client_ref(server_ref), body, ref}

    broadcast_from!(endpoint, server_ref, message)

    receive do
      {:ok, ^ref} -> nil
      {:error, ^ref} -> nil
    after
      opts[:window_ms] -> :request_timeout
    end
  end

  ## Session handling

  defp new_session(conn, endpoint, handler, opts) do
    priv_topic =
      "phx:lp:" <>
        Base.encode64(:crypto.strong_rand_bytes(16)) <>
        (System.system_time(:millisecond) |> Integer.to_string())

    keys = Keyword.get(opts, :connect_info, [])

    conn = maybe_auth_token_from_header(conn, opts[:auth_token])

    connect_info =
      Transport.connect_info(conn, endpoint, keys, Keyword.take(opts, @connect_info_opts))

    arg = {endpoint, handler, opts, conn.params, priv_topic, connect_info}
    spec = {Phoenix.Transports.LongPoll.Server, arg}

    case DynamicSupervisor.start_child(Phoenix.Transports.LongPoll.Supervisor, spec) do
      :ignore ->
        conn |> put_status(:forbidden) |> status_json()

      {:ok, server_pid} ->
        data = {:v1, endpoint.config(:endpoint_id), server_pid, priv_topic}
        token = sign_token(endpoint, data, opts)
        # the batch tells clients that we keep messages until they acknowledge them
        conn |> put_status(:gone) |> status_token_messages_json(token, [], 0)
    end
  end

  defp listen(conn, server_ref, token, endpoint, opts) do
    ref = make_ref()
    client_ref = client_ref(server_ref)

    # the last batch the client received, sent by clients that acknowledge
    ack = int_param(conn, "ack")

    flush =
      case ack do
        # TODO: Remove the nil case in Phoenix 1.10. Phoenix 1.8 clients don't send
        # an ack. Phoenix 1.9 clients only omit it after their session reached a 1.8 node.
        nil -> {:flush, client_ref, ref}
        ack -> {:flush, client_ref, ref, ack}
      end

    broadcast_from!(endpoint, server_ref, flush)

    {status, messages, batch} =
      receive do
        # Phoenix 1.8 servers, and newer servers answering a flush without ack,
        # reply without batch.
        #
        # TODO: Remove the clauses without batch in Phoenix 1.10
        {:messages, messages, ^ref} ->
          {:ok, messages, nil}

        {:messages, messages, ^ref, batch} ->
          {:ok, messages, batch}

        {:now_available, ^ref} ->
          broadcast_from!(endpoint, server_ref, flush)

          receive do
            {:messages, messages, ^ref} -> {:ok, messages, nil}
            {:messages, messages, ^ref, batch} -> {:ok, messages, batch}
          after
            opts[:window_ms] ->
              broadcast_from!(endpoint, server_ref, {:expired, client_ref, ref})
              {:no_content, [], ack}
          end
      after
        opts[:window_ms] ->
          # Without messages, the batch stays the one the client acknowledged. It tells
          # the client that we keep the messages, like we do with messages.
          broadcast_from!(endpoint, server_ref, {:expired, client_ref, ref})
          {:no_content, [], ack}
      end

    conn
    |> put_status(status)
    |> status_token_messages_json(token, messages, batch)
  end

  defp int_param(conn, key) do
    with value when is_binary(value) <- conn.params[key],
         {int, ""} <- Integer.parse(value) do
      int
    else
      _ -> nil
    end
  end

  # Accept the token from either location so that newer clients can use the
  # header while older clients continue to use params.
  defp fetch_token(conn) do
    case get_req_header(conn, @token_header) do
      [token | _] -> token
      [] -> conn.params["token"]
    end
  end

  # Retrieves the serialized `Phoenix.LongPoll.Server` pid
  # by publishing a message in the encrypted private topic.
  defp resume_session(%Plug.Conn{} = conn, endpoint, opts) do
    with token when is_binary(token) <- fetch_token(conn),
         {:ok, {:v1, id, pid, priv_topic}} <- verify_token(endpoint, token, opts) do
      server_ref = server_ref(endpoint.config(:endpoint_id), id, pid, priv_topic)

      new_conn =
        Plug.Conn.register_before_send(conn, fn conn ->
          unsubscribe(endpoint, server_ref)
          conn
        end)

      ref = make_ref()
      :ok = subscribe(endpoint, server_ref)
      broadcast_from!(endpoint, server_ref, {:subscribe, client_ref(server_ref), ref})

      receive do
        {:subscribe, ^ref} -> {:ok, new_conn, server_ref, token}
      after
        opts[:pubsub_timeout_ms] -> :error
      end
    else
      _ -> :error
    end
  end

  ## Helpers

  defp server_ref(endpoint_id, id, pid, topic) when is_pid(pid) do
    cond do
      node(pid) in Node.list() -> pid
      endpoint_id == id and Process.alive?(pid) -> pid
      true -> topic
    end
  end

  defp client_ref(topic) when is_binary(topic), do: topic
  defp client_ref(pid) when is_pid(pid), do: self()

  defp subscribe(endpoint, topic) when is_binary(topic),
    do: Phoenix.PubSub.subscribe(endpoint.config(:pubsub_server), topic)

  defp subscribe(_endpoint, pid) when is_pid(pid),
    do: :ok

  defp unsubscribe(endpoint, topic) when is_binary(topic),
    do: Phoenix.PubSub.unsubscribe(endpoint.config(:pubsub_server), topic)

  defp unsubscribe(_endpoint, pid) when is_pid(pid),
    do: :ok

  defp broadcast_from!(endpoint, topic, msg) when is_binary(topic),
    do: Phoenix.PubSub.broadcast_from!(endpoint.config(:pubsub_server), self(), topic, msg)

  defp broadcast_from!(_endpoint, pid, msg) when is_pid(pid),
    do: send(pid, msg)

  defp sign_token(endpoint, data, opts) do
    Phoenix.Token.sign(
      endpoint,
      Atom.to_string(endpoint.config(:pubsub_server)),
      data,
      opts[:crypto]
    )
  end

  defp verify_token(endpoint, signed, opts) do
    Phoenix.Token.verify(
      endpoint,
      Atom.to_string(endpoint.config(:pubsub_server)),
      signed,
      opts[:crypto]
    )
  end

  defp maybe_auth_token_from_header(conn, true) do
    case Plug.Conn.get_req_header(conn, "x-phoenix-authtoken") do
      [] ->
        conn

      [token | _] ->
        Plug.Conn.put_private(conn, :phoenix_transport_auth_token, token)
    end
  end

  defp maybe_auth_token_from_header(conn, _), do: conn

  defp status_json(conn, extra \\ %{}) do
    send_json(conn, Map.put(extra, "status", conn.status || 200))
  end

  # TODO: Remove in Phoenix 1.10, when every poll has a batch
  defp status_token_messages_json(conn, token, messages, nil) do
    send_json(conn, %{"status" => conn.status || 200, "token" => token, "messages" => messages})
  end

  defp status_token_messages_json(conn, token, messages, batch) do
    send_json(conn, %{
      "status" => conn.status || 200,
      "token" => token,
      "messages" => messages,
      "batch" => batch
    })
  end

  defp send_json(conn, data) do
    conn
    |> put_resp_header("content-type", "application/json; charset=utf-8")
    # When the token travels in a header, the poll URL is identical for every
    # session, so responses must never be stored or shared by a cache.
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, Phoenix.json_library().encode_to_iodata!(data))
  end
end
