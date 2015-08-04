defmodule Phoenix.Tranports.LongPollTest do
  use ExUnit.Case, async: true
  use RouterHelper

  Application.put_env(:lp_app, __MODULE__.Endpoint, [
    server: false,
    pubsub: [name: :phx_lp_pub, adapter: Phoenix.PubSub.PG2],
    secret_key_base: "reallylongsecretweneedtocheckeverywhereforaminimumlength"
  ])

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :lp_app
  end

  defmodule UserSocket do
    use Phoenix.Socket

    transport :longpoll, Phoenix.Transports.LongPoll,
      window_ms: 10_000,
      pubsub_timeout_ms: 100,
      crypto: [iterations: 1000, length: 32, digest: :sha256, cache: Plug.Keys]

    def connect(_params, socket), do: {:ok, socket}
    def id(_), do: "user_sockets:123"
  end

  alias Phoenix.Transports.LongPoll
  alias Phoenix.Socket.Transport

  defp new_socket do
    serializer = transport_opts()[:serializer]
    {:ok, socket} =
      Transport.connect(Endpoint, UserSocket, :longpool, LongPoll, serializer, %{})
    socket
  end

  defp transport_opts do
    UserSocket.__transport__(:longpoll) |> elem(1)
  end

  setup_all do
    capture_log fn -> Endpoint.start_link() end
    :ok
  end

  test "starts session with long poll server" do
    assert LongPoll.resume_session(%{}, Endpoint, transport_opts()) == :error
    {topic, token, server_pid} = LongPoll.start_session(Endpoint, new_socket(), transport_opts())
    assert Process.alive?(server_pid)
    assert Phoenix.Token.verify(Endpoint, "phx_lp_pub", token) ==
           {:ok, topic}
    assert LongPoll.resume_session(%{"token" => token}, Endpoint, transport_opts()) ==
           {:ok, topic}
  end

  test "cannot resume session if long poll server is dead" do
    {_topic, token, server_pid} = LongPoll.start_session(Endpoint, new_socket(), transport_opts())

    ref = Process.monitor(server_pid)
    GenServer.call(server_pid, :stop)
    assert_receive {:DOWN, ^ref, _, _, _}

    assert LongPoll.resume_session(%{"token" => token}, Endpoint, transport_opts()) ==
           :error
  end
end
