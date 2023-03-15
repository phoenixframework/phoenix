defmodule Phoenix.Transports.LongPoll do
  @moduledoc false
  @behaviour Plug

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
    case resume_session(conn.params, endpoint, opts) do
      {:ok, server_ref} ->
        listen(conn, server_ref, endpoint, opts)
      :error ->
        new_session(conn, endpoint, handler, opts)
    end
  end

  # Publish the message.
  defp dispatch(%{method: "POST"} = conn, endpoint, _, opts) do
    case resume_session(conn.params, endpoint, opts) do
      {:ok, server_ref} ->
        publish(conn, server_ref, endpoint, opts)
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
        # we need to match on both v1 and v2 protocol, as well as wrap for backwards compat
        batch =
          case get_req_header(conn, "content-type") do
            ["application/x-ndjson"] -> String.split(body, ["\n", "\r\n"])
            _ -> [body]
          end

        {conn, status} =
          Enum.reduce_while(batch, {conn, nil}, fn msg, {conn, _status} ->
            case transport_dispatch(endpoint, server_ref, msg, opts) do
              :ok -> {:cont, {conn, :ok}}
              :request_timeout = timeout -> {:halt, {conn, timeout}}
            end
          end)

        conn |> put_status(status) |> status_json()

      _ ->
        raise Plug.BadRequestError
    end
  end

  defp transport_dispatch(endpoint, server_ref, body, opts) do
    ref = make_ref()
    broadcast_from!(endpoint, server_ref, {:dispatch, client_ref(server_ref), body, ref})

    receive do
      {:ok, ^ref} -> :ok
      {:error, ^ref} -> :ok
    after
      opts[:window_ms] -> :request_timeout
    end
  end

  ## Session handling

  defp new_session(conn, endpoint, handler, opts) do
    priv_topic =
      "phx:lp:"
      <> Base.encode64(:crypto.strong_rand_bytes(16))
      <> (System.system_time(:millisecond) |> Integer.to_string)

    keys = Keyword.get(opts, :connect_info, [])
    connect_info = Transport.connect_info(conn, endpoint, keys)
    arg = {endpoint, handler, opts, conn.params, priv_topic, connect_info}
    spec = {Phoenix.Transports.LongPoll.Server, arg}

    case DynamicSupervisor.start_child(Phoenix.Transports.LongPoll.Supervisor, spec) do
      :ignore ->
        conn |> put_status(:forbidden) |> status_json()

      {:ok, server_pid} ->
        data  = {:v1, endpoint.config(:endpoint_id), server_pid, priv_topic}
        token = sign_token(endpoint, data, opts)
        conn |> put_status(:gone) |> status_token_messages_json(token, [])
    end
  end

  defp listen(conn, server_ref, endpoint, opts) do
    ref = make_ref()
    broadcast_from!(endpoint, server_ref, {:flush, client_ref(server_ref), ref})

    {status, messages} =
      receive do
        {:messages, messages, ^ref} ->
          {:ok, messages}

        {:now_available, ^ref} ->
          broadcast_from!(endpoint, server_ref, {:flush, client_ref(server_ref), ref})
          receive do
            {:messages, messages, ^ref} -> {:ok, messages}
          after
            opts[:window_ms]  -> {:no_content, []}
          end
      after
        opts[:window_ms] ->
          {:no_content, []}
      end

    conn
    |> put_status(status)
    |> status_token_messages_json(conn.params["token"], messages)
  end

  # Retrieves the serialized `Phoenix.LongPoll.Server` pid
  # by publishing a message in the encrypted private topic.
  defp resume_session(%{"token" => token}, endpoint, opts) do
    case verify_token(endpoint, token, opts) do
      {:ok, {:v1, id, pid, priv_topic}} ->
        server_ref = server_ref(endpoint.config(:endpoint_id), id, pid, priv_topic)

        ref = make_ref()
        :ok = subscribe(endpoint, server_ref)
        broadcast_from!(endpoint, server_ref, {:subscribe, client_ref(server_ref), ref})

        receive do
          {:subscribe, ^ref} -> {:ok, server_ref}
        after
          opts[:pubsub_timeout_ms]  -> :error
        end

      _ ->
        :error
    end
  end

  defp resume_session(_params, _endpoint, _opts), do: :error

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
    do: Phoenix.PubSub.subscribe(endpoint.config(:pubsub_server), topic, link: true)
  defp subscribe(_endpoint, pid) when is_pid(pid),
    do: :ok

  defp broadcast_from!(endpoint, topic, msg) when is_binary(topic),
    do: Phoenix.PubSub.broadcast_from!(endpoint.config(:pubsub_server), self(), topic, msg)
  defp broadcast_from!(_endpoint, pid, msg) when is_pid(pid),
    do: send(pid, msg)

  defp sign_token(endpoint, data, opts) do
    Phoenix.Token.sign(endpoint, Atom.to_string(endpoint.config(:pubsub_server)), data, opts[:crypto])
  end

  defp verify_token(endpoint, signed, opts) do
    Phoenix.Token.verify(endpoint, Atom.to_string(endpoint.config(:pubsub_server)), signed, opts[:crypto])
  end

  defp status_json(conn) do
    send_json(conn, %{"status" => conn.status || 200})
  end

  defp status_token_messages_json(conn, token, messages) do
    send_json(conn, %{"status" => conn.status || 200, "token" => token, "messages" => messages})
  end

  defp send_json(conn, data) do
    conn
    |> put_resp_header("content-type", "application/json; charset=utf-8")
    |> send_resp(200, Phoenix.json_library().encode_to_iodata!(data))
  end
end
