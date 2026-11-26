defmodule Phoenix.Transports.LongPoll do
  @moduledoc false
  @behaviour Plug

  # The maximum is 10MB but read_body will cap the whole request at ~8MB,
  # so this acts as a secondary protection mechanism.
  @max_base64_size 10_000_000
  @max_poll_batch_size 100
  @connect_info_opts [:check_csrf]
  @token_header "x-phoenix-longpoll-token"
  # The params clients use to number their messages and to mark the first polls
  # after a failed request with "phx:resume", which are not for the socket.
  @transport_params ["phx:ack", "phx:seq", "phx:resume"]

  import Plug.Conn
  alias Phoenix.Socket.{V1, V2, Transport}
  alias Phoenix.Transports.Session
  require Logger

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
      {:ok, new_conn, server_ref, priv_topic, token} ->
        listen(new_conn, {server_ref, priv_topic}, token, endpoint, opts)

      :error ->
        new_session(conn, endpoint, handler, opts)
    end
  end

  # Publish the message.
  defp dispatch(%{method: "POST"} = conn, endpoint, _, opts) do
    case resume_session(conn, endpoint, opts) do
      {:ok, new_conn, server_ref, _priv_topic, _token} ->
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
    # the number of the first message, as clients number their messages
    case int_param(conn, "phx:seq") do
      nil -> reject_unnumbered(conn, "phx:seq")
      seq -> publish(conn, server_ref, seq, endpoint, opts)
    end
  end

  defp publish(conn, server_ref, seq, endpoint, opts) do
    case read_body(conn, []) do
      {:ok, body, conn} ->
        # We need to match on both v1 and v2 protocol, as well as wrap for backwards compat
        messages =
          case get_req_header(conn, "content-type") do
            ["application/x-ndjson"] ->
              body
              |> String.splitter(["\n", "\r\n"])
              |> Stream.take(@max_poll_batch_size)
              |> Stream.map(fn
                "[" <> _ = txt -> {txt, :text}
                base64 -> {safe_decode64!(base64), :binary}
              end)

            _ ->
              [{body, :text}]
          end

        status =
          messages
          |> Stream.with_index(seq)
          |> Enum.find_value(fn {msg, seq} ->
            transport_dispatch(endpoint, server_ref, msg, seq, opts)
          end)

        # the seq tells clients that we drop the messages they send again
        conn |> put_status(status || :ok) |> status_json(%{"seq" => seq})

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

    broadcast_from!(endpoint, server_ref, {:dispatch, client_ref(server_ref), body, ref, seq})

    receive do
      {:ok, ^ref} -> nil
      {:error, ^ref} -> nil
      # the client uses another transport and did not resume the session to long poll
      {:rejected, ^ref} -> :gone
    after
      opts[:window_ms] -> :request_timeout
    end
  end

  ## Session handling

  defp new_session(conn, endpoint, handler, opts) do
    priv_topic = Session.priv_topic()
    keys = Keyword.get(opts, :connect_info, [])

    conn = maybe_auth_token_from_header(conn, opts[:auth_token])

    connect_info =
      Transport.connect_info(conn, endpoint, keys, Keyword.take(opts, @connect_info_opts))

    params = Map.drop(conn.params, @transport_params)
    arg = {endpoint, handler, opts, params, priv_topic, connect_info}
    spec = {Session, arg}

    case DynamicSupervisor.start_child(Session.Supervisor, spec) do
      :ignore ->
        conn |> put_status(:forbidden) |> status_json()

      {:ok, server_pid} ->
        data = {:v1, endpoint.config(:endpoint_id), server_pid, priv_topic}
        token = Session.sign_token(endpoint, data, opts)
        # The "last" field tells clients that we number our messages and keep them
        # until they are acknowledged, so they can retry failed requests.
        # A new session has not sent any messages yet, so it is 0.
        conn |> put_status(:gone) |> status_token_messages_json(token, [], 0)
    end
  end

  defp listen(conn, {server_ref, priv_topic}, token, endpoint, opts) do
    # the last message the client received, as clients acknowledge our messages
    with {:ok, ack} <- fetch_ack(conn),
         {:ok, wait?} <- check_resume(conn, server_ref, priv_topic, endpoint, opts) do
      poll(conn, server_ref, token, ack, endpoint, opts, wait?)
    else
      {:error, :unnumbered} ->
        reject_unnumbered(conn, "phx:ack")

      {:error, :rejected} ->
        # the session is gone, so the client starts a new one
        conn |> put_status(:gone) |> status_json()
    end
  end

  defp fetch_ack(conn) do
    case int_param(conn, "phx:ack") do
      nil -> {:error, :unnumbered}
      ack -> {:ok, ack}
    end
  end

  # Clients resume the session with the polls after a failed request, so the
  # socket can check the connection again. The client waits for the answer to
  # this poll before it reports that it recovered, so we answer it without
  # waiting for messages.
  defp check_resume(
         %{params: %{"phx:resume" => _}} = conn,
         server_ref,
         priv_topic,
         endpoint,
         opts
       ) do
    keys = Keyword.get(opts, :connect_info, [])
    conn = maybe_auth_token_from_header(conn, opts[:auth_token])

    connect_info =
      Transport.connect_info(conn, endpoint, keys, Keyword.take(opts, @connect_info_opts))

    info = %{
      endpoint: endpoint,
      transport: :longpoll,
      options: opts,
      params: Map.drop(conn.params, @transport_params),
      connect_info: connect_info
    }

    ref = make_ref()

    broadcast_from!(
      endpoint,
      server_ref,
      {:resume, client_ref(server_ref), ref, info, priv_topic}
    )

    receive do
      {:resumed, ^ref} -> {:ok, false}
      {:rejected, ^ref} -> {:error, :rejected}
    after
      # The session handles the resume before the flush we send next, as both come from
      # this process. If it is slow to answer, for example because resume/3 queries the
      # database, we poll anyway: a session that rejects the resume stops before it sends
      # us messages, so the poll expires and the next request gets 410.
      opts[:pubsub_timeout_ms] -> {:ok, false}
    end
  end

  defp check_resume(_conn, _server_ref, _priv_topic, _endpoint, _opts), do: {:ok, true}

  defp poll(conn, server_ref, token, ack, endpoint, opts, wait?) do
    ref = make_ref()
    client_ref = client_ref(server_ref)
    flush = {:flush, client_ref, ref, ack}
    broadcast_from!(endpoint, server_ref, flush)

    # The session only answers the flush when it has messages,
    # so its echo then tells us that it has none.
    echo_ref = if not wait?, do: echo(endpoint, server_ref, client_ref)

    result =
      receive do
        {:messages, messages, ^ref, last} ->
          {:ok, messages, last}

        {:rejected, ^ref} ->
          :rejected

        {:subscribe, ^echo_ref} ->
          expire(endpoint, server_ref, client_ref, ref, ack)

        {:now_available, ^ref} ->
          broadcast_from!(endpoint, server_ref, flush)

          receive do
            {:messages, messages, ^ref, last} -> {:ok, messages, last}
            {:rejected, ^ref} -> :rejected
          after
            opts[:window_ms] -> expire(endpoint, server_ref, client_ref, ref, ack)
          end
      after
        opts[:window_ms] -> expire(endpoint, server_ref, client_ref, ref, ack)
      end

    case result do
      {status, messages, last} ->
        conn
        |> put_status(status)
        |> status_token_messages_json(token, messages, last)

      :rejected ->
        # The client uses another transport and did not resume the session to long
        # poll, so the socket did not check this request. The client starts a new session.
        conn |> put_status(:gone) |> status_json()
    end
  end

  # The session handles our requests in order and echoes a subscribe, so the echo
  # tells us that it handled the requests we sent before. When its answer to one of
  # them arrives first, we leave the echo in the mailbox, as waiting for it would
  # delay the response. With Cowboy, the request process stops after the response.
  # Bandit ignores unhandled messages.
  defp echo(endpoint, server_ref, client_ref) do
    echo_ref = make_ref()
    broadcast_from!(endpoint, server_ref, {:subscribe, client_ref, echo_ref})
    echo_ref
  end

  # Stops waiting for messages. The session can still answer our flush afterwards.
  # It keeps the messages until the client acknowledges them, so the client gets
  # them with its next poll. Without messages, the last message is the one the client
  # acknowledged. It tells the client that we keep the messages, like we do with messages.
  defp expire(endpoint, server_ref, client_ref, ref, ack) do
    broadcast_from!(endpoint, server_ref, {:expired, client_ref, ref})
    {:no_content, [], ack}
  end

  # Clients number their messages since Phoenix v1.8.18. A browser that still runs an
  # older client fails here, starts a new session and fails again until the page reloads.
  defp reject_unnumbered(conn, param) do
    Logger.error(
      "Phoenix.Transports.LongPoll rejected a #{conn.method} request without the #{param} " <>
        "parameter. Long polling requires the phoenix.js client of Phoenix v1.8.18 or later. " <>
        "Browsers that still run an older client must reload the page"
    )

    conn |> put_status(:gone) |> status_json()
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

  # Retrieves the serialized `Phoenix.Transports.Session` pid
  # by publishing a message in the encrypted private topic.
  defp resume_session(%Plug.Conn{} = conn, endpoint, opts) do
    with token when is_binary(token) <- fetch_token(conn),
         {:ok, {:v1, id, pid, priv_topic}} <- Session.verify_token(endpoint, token, opts) do
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
        {:subscribe, ^ref} -> {:ok, new_conn, server_ref, priv_topic, token}
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

  defp status_token_messages_json(conn, token, messages, last) do
    send_json(conn, %{
      "status" => conn.status || 200,
      "token" => token,
      "messages" => messages,
      "last" => last
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
