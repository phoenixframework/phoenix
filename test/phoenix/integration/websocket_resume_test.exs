Code.require_file("../../support/websocket_client.exs", __DIR__)
Code.require_file("../../support/http_client.exs", __DIR__)

defmodule Phoenix.Integration.WebSocketResumeTest do
  use ExUnit.Case, async: false

  alias Phoenix.Integration.{HTTPClient, WebsocketClient}
  alias Phoenix.Socket.{V2, Message}
  alias __MODULE__.Endpoint

  @moduletag :capture_log
  @port 5810

  Application.put_env(:phoenix, Endpoint,
    https: false,
    http: [port: @port],
    debug_errors: false,
    server: true,
    drainer: false,
    pubsub_server: __MODULE__,
    secret_key_base: String.duplicate("a", 64)
  )

  defmodule RoomChannel do
    use Phoenix.Channel

    def join(topic, params, socket) do
      Process.register(self(), String.to_atom(params["name"] || topic))

      if params["resumable"] == false do
        {:ok, socket}
      else
        {:ok, Phoenix.Channel.resumable(socket)}
      end
    end

    def handle_in("ping", %{"n" => n}, socket) do
      {:reply, {:ok, %{n: n}}, socket}
    end

    def handle_info({:push, n}, socket) do
      push(socket, "tick", %{n: n})
      {:noreply, socket}
    end

    def handle_info(:stop, socket) do
      {:stop, :normal, socket}
    end

    def handle_info({:broadcast, n}, socket) do
      broadcast_from(socket, "news", %{n: n})
      {:noreply, socket}
    end
  end

  defmodule UserSocket do
    use Phoenix.Socket, log: false

    channel "room:*", RoomChannel

    def connect(_params, socket, _connect_info), do: {:ok, socket}
    def id(_socket), do: nil
  end

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix

    socket "/ws", UserSocket,
      websocket: [resume: [timeout: 500]],
      longpoll: [window_ms: 1_000]
  end

  setup_all do
    capture_log(fn -> start_supervised!(Endpoint) end)
    start_supervised!({Phoenix.PubSub, name: __MODULE__})
    :ok
  end

  defp capture_log(fun), do: ExUnit.CaptureLog.capture_log(fun)

  @url "ws://127.0.0.1:#{@port}/ws/websocket?vsn=2.0.0&phx_resumable=true"

  defp topic, do: "room:#{System.unique_integer([:positive])}"

  defp connect(url \\ @url) do
    {:ok, client} = WebsocketClient.connect(self(), url, V2.JSONSerializer)
    client
  end

  defp join_resumable(client, topic, name \\ nil) do
    WebsocketClient.join(client, topic, %{"name" => name})
    assert_receive %Message{event: "phx_reply", topic: ^topic, payload: %{"status" => "ok"}}

    assert_receive %Message{
      event: "phx_resumable",
      topic: ^topic,
      join_ref: join_ref,
      payload: %{"token" => token}
    }

    channel = Process.whereis(String.to_atom(name || topic))
    %{topic: topic, token: token, join_ref: join_ref, channel: channel}
  end

  defp send_raw(client, frame) do
    WebsocketClient.send(client, {:text, Phoenix.json_library().encode!(frame)})
  end

  # takes the info of joined channels with the number of frames received for each
  defp resume(client, claimed) do
    [{%{token: token}, _} | _] = claimed
    channels = for {info, received} <- claimed, do: [info.topic, info.join_ref, received]
    send_raw(client, [nil, "1000", "phoenix", "phx_resume", %{token: token, channels: channels}])
  end

  defp close(client) do
    ref = Process.monitor(client)
    WebsocketClient.close(client)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  test "resumes a channel and replays the frames the client missed" do
    topic = topic()
    client = connect()
    info = join_resumable(client, topic)

    send(info.channel, {:push, 1})
    assert_receive %Message{event: "tick", payload: %{"n" => 1}}
    close(client)

    # pushed while there is no connection
    send(info.channel, {:push, 2})
    send(info.channel, {:push, 3})

    client = connect()
    # we received the first tick after phx_resumable
    resume(client, [{info, 1}])

    assert_receive %Message{
      event: "phx_reply",
      topic: "phoenix",
      payload: %{"status" => "ok", "response" => %{"channels" => [[^topic, _]]}}
    }

    assert_receive %Message{event: "tick", payload: %{"n" => 2}}
    assert_receive %Message{event: "tick", payload: %{"n" => 3}}
    refute_received %Message{event: "tick", payload: %{"n" => 1}}

    assert Process.alive?(info.channel)
    send(info.channel, {:push, 4})
    assert_receive %Message{event: "tick", payload: %{"n" => 4}}

    send_raw(client, [info.join_ref, "1001", topic, "ping", %{n: 1}])
    assert_receive %Message{event: "phx_reply", ref: "1001", payload: %{"status" => "ok"}}

    # a message the client resends after resuming is only handled once
    send_raw(client, [info.join_ref, "1001", topic, "ping", %{n: 1}])
    refute_receive %Message{event: "phx_reply", ref: "1001"}
  end

  test "resumes while the previous connection still seems alive" do
    topic = topic()
    old_client = connect()
    info = join_resumable(old_client, topic)

    send(info.channel, {:push, 1})
    assert_receive %Message{event: "tick", payload: %{"n" => 1}}

    ref = Process.monitor(old_client)
    client = connect()
    # the first tick got lost on the half-open connection
    resume(client, [{info, 0}])

    assert_receive %Message{event: "phx_reply", topic: "phoenix", payload: %{"status" => "ok"}}
    assert_receive %Message{event: "tick", payload: %{"n" => 1}}

    # the server closes the previous connection
    assert_receive {:DOWN, ^ref, _, _, _}

    send(info.channel, {:push, 2})
    assert_receive %Message{event: "tick", payload: %{"n" => 2}}
  end

  test "fails to resume after the timeout and the channel stops" do
    topic = topic()
    client = connect()
    info = join_resumable(client, topic)
    channel_ref = Process.monitor(info.channel)

    WebsocketClient.close(client)
    assert_receive {:DOWN, ^channel_ref, _, _, _}, 2_000

    client = connect()
    resume(client, [{info, 0}])

    assert_receive %Message{
      event: "phx_reply",
      topic: "phoenix",
      payload: %{"status" => "error", "response" => %{"reason" => _}}
    }
  end

  test "relays broadcasts with the join_ref and replays them" do
    topic = topic()
    client = connect()
    info = join_resumable(client, topic)
    other = connect()
    other_info = join_resumable(other, topic, "other:" <> topic)
    join_ref = info.join_ref

    send(other_info.channel, {:broadcast, 1})
    assert_receive %Message{event: "news", join_ref: ^join_ref, payload: %{"n" => 1}}
    close(client)

    send(other_info.channel, {:broadcast, 2})

    client = connect()
    resume(client, [{info, 1}])
    assert_receive %Message{event: "phx_reply", topic: "phoenix", payload: %{"status" => "ok"}}
    assert_receive %Message{event: "news", join_ref: ^join_ref, payload: %{"n" => 2}}
    refute_received %Message{event: "news", payload: %{"n" => 1}}
  end

  test "channels on a socket share a session and resume independently" do
    {topic1, topic2, topic3} = {topic(), topic(), topic()}
    client = connect()
    info1 = join_resumable(client, topic1)
    info2 = join_resumable(client, topic2)
    info3 = join_resumable(client, topic3)
    assert info1.token == info2.token

    send(info1.channel, {:push, 1})
    send(info2.channel, {:push, 1})
    assert_receive %Message{event: "tick", topic: ^topic1}
    assert_receive %Message{event: "tick", topic: ^topic2}

    # the client acknowledges the tick on the first channel only
    send_raw(client, [nil, nil, "phoenix", "phx_ack", %{channels: [[topic1, info1.join_ref, 1]]}])
    close(client)

    send(info1.channel, {:push, 2})
    send(info2.channel, {:push, 2})
    channel3_ref = Process.monitor(info3.channel)

    # the third channel is not claimed, for example because it was left meanwhile
    client = connect()
    resume(client, [{info1, 1}, {info2, 0}])

    assert_receive %Message{
      event: "phx_reply",
      topic: "phoenix",
      payload: %{"status" => "ok", "response" => %{"channels" => channels}}
    }

    assert Enum.sort(channels) ==
             Enum.sort([[topic1, info1.join_ref], [topic2, info2.join_ref]])

    assert_receive %Message{event: "tick", topic: ^topic1, payload: %{"n" => 2}}
    assert_receive %Message{event: "tick", topic: ^topic2, payload: %{"n" => 1}}
    assert_receive %Message{event: "tick", topic: ^topic2, payload: %{"n" => 2}}
    refute_received %Message{event: "tick", topic: ^topic1, payload: %{"n" => 1}}
    assert_receive {:DOWN, ^channel3_ref, _, _, {:shutdown, :closed}}
  end

  test "delivers the last frames of a channel that stopped while parked" do
    topic = topic()
    client = connect()
    info = join_resumable(client, topic)
    close(client)

    channel_ref = Process.monitor(info.channel)
    send(info.channel, {:push, 1})
    send(info.channel, :stop)
    assert_receive {:DOWN, ^channel_ref, _, _, _}

    client = connect()
    resume(client, [{info, 0}])
    assert_receive %Message{event: "phx_reply", topic: "phoenix", payload: %{"status" => "ok"}}
    assert_receive %Message{event: "tick", topic: ^topic, payload: %{"n" => 1}}
    assert_receive %Message{event: "phx_close", topic: ^topic}
  end

  test "stops when the connected client does not acknowledge" do
    topic = topic()
    client = connect()
    info = join_resumable(client, topic)
    channel_ref = Process.monitor(info.channel)

    ack = fn n ->
      send_raw(client, [nil, nil, "phoenix", "phx_ack", %{channels: [[topic, info.join_ref, n]]}])
    end

    # acknowledging keeps the channel alive across several checks
    for n <- 1..6 do
      send(info.channel, {:push, n})
      assert_receive %Message{event: "tick", payload: %{"n" => ^n}}
      ack.(n)
      Process.sleep(200)
    end

    assert Process.alive?(info.channel)

    send(info.channel, {:push, 7})
    assert_receive %Message{event: "tick", payload: %{"n" => 7}}
    assert_receive {:DOWN, ^channel_ref, _, _, _}, 1_500
  end

  defp longpoll(method, params, body \\ nil) do
    url =
      "http://127.0.0.1:#{@port}/ws/longpoll?" <>
        URI.encode_query(Map.put(params, "vsn", "2.0.0"))

    body = if body, do: Phoenix.json_library().encode!(body), else: ""
    {:ok, resp} = HTTPClient.request(method, url, %{"content-type" => "application/json"}, body)
    resp = Phoenix.json_library().decode!(resp.body)

    messages =
      for msg <- resp["messages"] || [], do: V2.JSONSerializer.decode!(msg, opcode: :text)

    Map.put(resp, "messages", messages)
  end

  # polls until we received the given number of messages, acknowledging them
  defp longpoll_messages(lp, count, acc \\ []) do
    if length(acc) >= count do
      {lp, acc}
    else
      resp = longpoll(:get, %{"token" => lp.token, "ack" => lp.ack})
      lp = %{lp | ack: resp["batch"] || lp.ack}
      longpoll_messages(lp, count, acc ++ resp["messages"])
    end
  end

  defp resume_over_longpoll(info, received) do
    %{"status" => 410, "token" => token} = longpoll(:get, %{})
    lp = %{token: token, ack: 0}

    resume = [
      nil,
      "1",
      "phoenix",
      "phx_resume",
      %{token: info.token, channels: [[info.topic, info.join_ref, received]]}
    ]

    assert %{"status" => 200} = longpoll(:post, %{"token" => token}, resume)
    lp
  end

  test "releases the channels to a long poll connection" do
    topic = topic()
    client = connect()
    info = join_resumable(client, topic)
    {:ok, session, _nonce} = Phoenix.Socket.ResumeSession.verify_token(Endpoint, info.token)
    session_ref = Process.monitor(session)

    send(info.channel, {:push, 1})
    assert_receive %Message{event: "tick", payload: %{"n" => 1}}
    close(client)

    send(info.channel, {:push, 2})
    send(info.channel, {:push, 3})

    lp = resume_over_longpoll(info, 1)
    {lp, [reply, tick2, tick3]} = longpoll_messages(lp, 3)

    assert %Message{
             event: "phx_reply",
             topic: "phoenix",
             payload: %{
               "status" => "ok",
               "response" => %{"released" => true, "channels" => [[^topic, _]]}
             }
           } = reply

    assert %Message{event: "tick", payload: %{"n" => 2}} = tick2
    assert %Message{event: "tick", payload: %{"n" => 3}} = tick3

    # the session hands the channel over and stops, long polling keeps the channel from now on
    assert_receive {:DOWN, ^session_ref, _, _, {:shutdown, :released}}
    assert Process.alive?(info.channel)

    send(info.channel, {:push, 4})
    {lp, [tick4]} = longpoll_messages(lp, 1)
    assert %Message{event: "tick", payload: %{"n" => 4}} = tick4

    ping = [info.join_ref, "2", topic, "ping", %{n: 1}]
    assert %{"status" => 200} = longpoll(:post, %{"token" => lp.token}, ping)
    {_lp, [pong]} = longpoll_messages(lp, 1)
    assert %Message{event: "phx_reply", ref: "2", payload: %{"status" => "ok"}} = pong
  end

  test "keeps the order of frames sent while the channels are released" do
    topic = topic()
    client = connect()
    info = join_resumable(client, topic)
    {:ok, session, _nonce} = Phoenix.Socket.ResumeSession.verify_token(Endpoint, info.token)
    close(client)

    # the first tick is pushed before the channel sees the handover, so it goes
    # through the session, which we hold up until the second tick went directly
    :sys.suspend(info.channel)
    send(info.channel, {:push, 1})
    lp = resume_over_longpoll(info, 0)
    send(info.channel, {:push, 2})
    :sys.suspend(session)
    :sys.resume(info.channel)
    :sys.get_state(info.channel)
    :sys.resume(session)

    {_lp, [_reply | ticks]} = longpoll_messages(lp, 3)
    assert Enum.map(ticks, & &1.payload["n"]) == [1, 2]
  end

  test "reports a channel that stops while it is released once" do
    topic = topic()
    client = connect()
    info = join_resumable(client, topic)
    close(client)

    # the channel stops before it sees the handover, so the session reports it
    :sys.suspend(info.channel)
    send(info.channel, :stop)
    lp = resume_over_longpoll(info, 0)
    :sys.resume(info.channel)

    {lp, [_reply, close]} = longpoll_messages(lp, 2)
    assert %Message{event: "phx_close", topic: ^topic} = close

    # a ping makes sure that nothing else was sent before it
    assert %{"status" => 200} =
             longpoll(:post, %{"token" => lp.token}, [nil, "2", "phoenix", "heartbeat", %{}])

    assert {_lp, [%Message{event: "phx_reply", ref: "2"}]} = longpoll_messages(lp, 1)
  end

  test "channels that don't opt in stop with the connection" do
    topic = topic()
    client = connect()
    WebsocketClient.join(client, topic, %{"resumable" => false})
    assert_receive %Message{event: "phx_reply", topic: ^topic, payload: %{"status" => "ok"}}
    refute_receive %Message{event: "phx_resumable"}

    channel_ref = topic |> String.to_atom() |> Process.whereis() |> Process.monitor()
    WebsocketClient.close(client)
    assert_receive {:DOWN, ^channel_ref, _, _, _}
  end

  test "clients that don't support resuming don't get resumable channels" do
    topic = topic()
    client = connect("ws://127.0.0.1:#{@port}/ws/websocket?vsn=2.0.0")
    WebsocketClient.join(client, topic, %{})
    assert_receive %Message{event: "phx_reply", topic: ^topic, payload: %{"status" => "ok"}}
    refute_receive %Message{event: "phx_resumable"}
  end
end
