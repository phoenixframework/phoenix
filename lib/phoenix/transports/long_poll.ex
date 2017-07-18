defmodule Phoenix.Transports.LongPoll do
  @moduledoc """
  Socket transport for long poll clients.

  ## Configuration

  The long poll is configurable in your socket:

      transport :longpoll, Phoenix.Transports.LongPoll,
        window_ms: 10_000,
        pubsub_timeout_ms: 2_000,
        transport_log: false,
        crypto: [max_age: 1209600]

    * `:window_ms` - how long the client can wait for new messages
      in its poll request

    * `:pubsub_timeout_ms` - how long a request can wait for the
      pubsub layer to respond

    * `:crypto` - options for verifying and signing the token, accepted
      by `Phoenix.Token`. By default tokens are valid for 2 weeks

    * `:transport_log` - if the transport layer itself should log and, if so, the level

    * `:check_origin` - if we should check the origin of requests when the
      origin header is present. It defaults to true and, in such cases,
      it will check against the host value in `YourApp.Endpoint.config(:url)[:host]`.
      It may be set to `false` (not recommended) or to a list of explicitly
      allowed origins

    * `:code_reloader` - optionally override the default `:code_reloader` value
      from the socket's endpoint
  """

  ## Transport callbacks

  @behaviour Phoenix.Socket.Transport
  alias Phoenix.Transports.{V2, LongPollSerializer}

  def default_config() do
    [window_ms: 10_000,
     pubsub_timeout_ms: 2_000,
     serializer: [{Phoenix.Transports.LongPollSerializer, "~> 1.0.0"},
                  {Phoenix.Transports.V2.LongPollSerializer, "~> 2.0.0"}],
     transport_log: false,
     crypto: [max_age: 1209600]]
  end

  ## Plug callbacks

  @behaviour Plug

  import Plug.Conn
  alias Phoenix.Socket.Transport

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, {endpoint, handler, transport}) do
    {_, opts} = handler.__transport__(transport)

    conn
    |> code_reload(opts, endpoint)
    |> fetch_query_params
    |> put_resp_header("access-control-allow-origin", "*")
    |> Plug.Conn.fetch_query_params
    |> Transport.transport_log(opts[:transport_log])
    |> Transport.force_ssl(handler, endpoint, opts)
    |> Transport.check_origin(handler, endpoint, opts, &status_json(&1, %{}))
    |> dispatch(endpoint, handler, transport, opts)
  end

  defp dispatch(%{halted: true} = conn, _, _, _, _) do
    conn
  end

  # Responds to pre-flight CORS requests with Allow-Origin-* headers.
  # We allow cross-origin requests as we always validate the Origin header.
  defp dispatch(%{method: "OPTIONS"} = conn, _, _, _, _) do
    headers = get_req_header(conn, "access-control-request-headers") |> Enum.join(", ")

    conn
    |> put_resp_header("access-control-allow-headers", headers)
    |> put_resp_header("access-control-allow-methods", "get, post, options")
    |> put_resp_header("access-control-max-age", "3600")
    |> send_resp(:ok, "")
  end

  # Starts a new session or listen to a message if one already exists.
  defp dispatch(%{method: "GET"} = conn, endpoint, handler, transport, opts) do
    case resume_session(conn.params, endpoint, opts) do
      {:ok, server_ref} ->
        listen(conn, server_ref, endpoint, opts)
      :error ->
        new_session(conn, endpoint, handler, transport, opts)
    end
  end

  # Publish the message encoded as a JSON body.
  defp dispatch(%{method: "POST"} = conn, endpoint, _, _, opts) do
    case resume_session(conn.params, endpoint, opts) do
      {:ok, server_ref} ->
        conn |> parse_json() |> publish(server_ref, endpoint, opts)
      :error ->
        conn |> put_status(:gone) |> status_json(%{})
    end
  end

  # All other requests should fail.
  defp dispatch(conn, _, _, _, _) do
    send_resp(conn, :bad_request, "")
  end

  ## Connection helpers

  # force application/json for xdomain clients
  defp parse_json(conn) do
    conn
    |> read_body([])
    |> decode(serializer(conn.params["vsn"]))
  end
  defp decode({:ok, body, conn}, serializer) do
    assign(conn, :message, serializer.decode!(body, []))
  rescue
    Phoenix.Socket.InvalidMessageError -> raise Plug.Parsers.ParseError
  end
  defp decode(_bad_request, _serializr), do: raise Plug.BadRequestError

  defp serializer("1." <> _ = _vsn), do: LongPollSerializer
  defp serializer("2." <> _ = _vsn), do: V2.LongPollSerializer
  defp serializer(nil), do: LongPollSerializer

  defp new_session(conn, endpoint, handler, transport, opts) do
    serializer = opts[:serializer]

    priv_topic =
      "phx:lp:"
      <> Base.encode64(:crypto.strong_rand_bytes(16))
      <> (System.system_time(:milliseconds) |> Integer.to_string)

    args = [endpoint, handler, transport, __MODULE__, serializer,
            conn.params, opts[:window_ms], priv_topic]

    supervisor = Module.concat(endpoint, "LongPoll.Supervisor")

    case Supervisor.start_child(supervisor, args) do
      {:ok, :undefined} ->
        conn |> put_status(:forbidden) |> status_json(%{})
      {:ok, server_pid} ->
        data  = {:v1, endpoint.config(:endpoint_id), server_pid, priv_topic}
        token = sign_token(endpoint, data, opts)
        conn |> put_status(:gone) |> status_json(%{token: token})
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
    |> status_json(%{token: conn.params["token"], messages: messages})
  end

  defp publish(conn, server_ref, endpoint, opts) do
    msg = conn.assigns.message

    case transport_dispatch(endpoint, server_ref, msg, opts) do
      :ok               -> conn |> put_status(:ok) |> status_json(%{})
      {:error, _reason} -> conn |> put_status(:unauthorized) |> status_json(%{})
    end
  end

  ## Endpoint helpers

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

  # Publishes a message to the pubsub system.
  defp transport_dispatch(endpoint, server_ref, msg, opts) do
    ref = make_ref()
    broadcast_from!(endpoint, server_ref, {:dispatch, client_ref(server_ref), msg, ref})

    receive do
      {:dispatch, ^ref}      -> :ok
      {:error, reason, ^ref} -> {:error, reason}
    after
      opts[:window_ms] -> {:error, :timeout}
    end
  end

  defp server_ref(endpoint_id, id, pid, topic) do
    if endpoint_id == id and Process.alive?(pid) do
      pid
    else
      topic
    end
  end

  defp client_ref(topic) when is_binary(topic), do: topic
  defp client_ref(pid) when is_pid(pid), do: self()

  defp subscribe(endpoint, topic) when is_binary(topic),
    do: Phoenix.PubSub.subscribe(endpoint.__pubsub_server__, topic, link: true)
  defp subscribe(_endpoint, pid) when is_pid(pid),
    do: :ok

  defp broadcast_from!(endpoint, topic, msg) when is_binary(topic),
    do: Phoenix.PubSub.broadcast_from!(endpoint.__pubsub_server__, self(), topic, msg)
  defp broadcast_from!(_endpoint, pid, msg) when is_pid(pid),
    do: send(pid, msg)

  defp sign_token(endpoint, data, opts) do
    Phoenix.Token.sign(endpoint, Atom.to_string(endpoint.__pubsub_server__), data, opts[:crypto])
  end

  defp verify_token(endpoint, signed, opts) do
    Phoenix.Token.verify(endpoint, Atom.to_string(endpoint.__pubsub_server__), signed, opts[:crypto])
  end

  defp status_json(conn, data) do
    status = Plug.Conn.Status.code(conn.status || 200)
    data   = Map.put(data, :status, status)
    conn
    |> put_status(200)
    |> Phoenix.Controller.json(data)
  end

  defp code_reload(conn, opts, endpoint) do
    reload? = Keyword.get(opts, :code_reloader, endpoint.config(:code_reloader))
    if reload?, do: Phoenix.CodeReloader.reload!(endpoint)

    conn
  end
end
