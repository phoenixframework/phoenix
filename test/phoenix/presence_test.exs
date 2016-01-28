defmodule Phoenix.PresenceTest do
  use ExUnit.Case, async: true
  alias Phoenix.Socket.Broadcast

  defmodule DefaultPresence do
    use Phoenix.Presence, otp_app: :phoenix
  end

  defmodule MyPresence do
    use Phoenix.Presence, otp_app: :phoenix

    def fetch(_topic, entries) do
      for {key, %{metas: metas}} <- entries, into: %{} do
        {key, %{metas: metas, extra: "extra"}}
      end
    end
  end

  Application.put_env(:phoenix, MyPresence, pubsub_server: PresPub)

  setup_all do
    {:ok, _} = Phoenix.PubSub.PG2.start_link(PresPub, pool_size: 1)
    assert {:ok, _pid} = MyPresence.start_link([])
    {:ok, pubsub: PresPub}
  end

  test "default fetch/2 returns pass-through data" do
    presences = %{"u1" => %{metas: [%{name: "u1", phx_ref: "ref"}]}}
    assert DefaultPresence.fetch("topic", presences) == presences
  end

  test "list/1 lists presences from tracker" do
    assert MyPresence.list("topic") == %{}
    assert MyPresence.track_presence(self(), "topic", "u1", %{name: "u1"}) == :ok
    assert %{"u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: _}]}} =
           MyPresence.list("topic")
  end

  test "handle_join and handle_leave broadcasts events with default fetched data", config do
    pid = spawn(fn -> :timer.sleep(:infinity) end)
    Phoenix.PubSub.subscribe(config.pubsub, self(), "topic")
    {:ok, _pid} = DefaultPresence.start_link(pubsub_server: config.pubsub)
    DefaultPresence.track_presence(pid, "topic", "u1", %{name: "u1"})

    assert_receive %Broadcast{topic: "topic", event: "presence_join", payload: %{
      "u1" => %{metas: [%{name: "u1", phx_ref: u1_ref}]}
    }}
    assert %{"u1" => %{metas: [%{name: "u1", phx_ref: ^u1_ref}]}} =
           DefaultPresence.list("topic")

    Process.exit(pid, :kill)
    assert_receive %Broadcast{topic: "topic", event: "presence_leave", payload: %{
      "u1" => %{metas: [%{name: "u1", phx_ref: ^u1_ref}]}
    }}
    assert DefaultPresence.list("topic") == %{}
  end

  test "handle_join and handle_leave broadcasts events with custom fetched data", config do
    pid = spawn(fn -> :timer.sleep(:infinity) end)
    Phoenix.PubSub.subscribe(config.pubsub, self(), "topic")
    MyPresence.track_presence(pid, "topic", "u1", %{name: "u1"})

    assert_receive %Broadcast{topic: "topic", event: "presence_join", payload: %{
      "u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: u1_ref}]}
    }}
    assert %{"u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: ^u1_ref}]}} =
           MyPresence.list("topic")

    Process.exit(pid, :kill)
    assert_receive %Broadcast{topic: "topic", event: "presence_leave", payload: %{
      "u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: ^u1_ref}]}
    }}
    assert MyPresence.list("topic") == %{}
  end

  test "list maintains join order when grouping", config do
    pid = spawn(fn -> :timer.sleep(:infinity) end)
    pid2 = spawn(fn -> :timer.sleep(:infinity) end)
    Phoenix.PubSub.subscribe(config.pubsub, self(), "topic")
    MyPresence.track_presence(pid, "topic", "u1", %{name: "1st"})
    MyPresence.track_presence(pid2, "topic", "u1", %{name: "2nd"})

    assert %{"u1" => %{metas: [%{name: "1st"}, %{name: "2nd"}]}} =
           MyPresence.list("topic")
  end
end
