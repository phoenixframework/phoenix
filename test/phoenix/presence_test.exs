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
    start_supervised!({Phoenix.PubSub, name: PresPub, pool_size: 1})
    start_supervised!(MyPresence)
    {:ok, pubsub: PresPub}
  end

  setup config do
    {:ok, topic: to_string(config.test)}
  end

  test "defines child_spec/1" do
    assert DefaultPresence.child_spec([]) == %{
             id: DefaultPresence,
             start:
               {Phoenix.Presence, :start_link,
                [
                  Phoenix.PresenceTest.DefaultPresence,
                  Phoenix.PresenceTest.DefaultPresence.TaskSupervisor,
                  [otp_app: :phoenix]
                ]},
             type: :supervisor
           }
  end

  test "default fetch/2 returns pass-through data", config do
    presences = %{"u1" => %{metas: [%{name: "u1", phx_ref: "ref"}]}}
    assert DefaultPresence.fetch(config.topic, presences) == presences
  end

  test "list/1 lists presences from tracker", config do
    assert MyPresence.list(config.topic) == %{}
    assert MyPresence.list(%Phoenix.Socket{topic: config.topic}) == %{}
    assert {:ok, _} = MyPresence.track(self(), config.topic, "u1", %{name: "u1"})

    assert %{"u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: _}]}} =
             MyPresence.list(config.topic)

    assert %{"u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: _}]}} =
             MyPresence.list(%Phoenix.Socket{topic: config.topic})
  end

  test "list/1 returns keys as strings", config do
    assert {:ok, _} = MyPresence.track(self(), config.topic, 1, %{name: "u1"})

    assert %{"1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: _}]}} =
             MyPresence.list(config.topic)
  end

  test "get_by_key/2 returns metadata for key", config do
    pid2 = spawn(fn -> :timer.sleep(:infinity) end)
    pid3 = spawn(fn -> :timer.sleep(:infinity) end)
    assert MyPresence.get_by_key(config.topic, 1) == []
    assert {:ok, _} = MyPresence.track(self(), config.topic, 1, %{name: "u1"})
    assert {:ok, _} = MyPresence.track(pid2, config.topic, 1, %{name: "u1.2"})
    assert {:ok, _} = MyPresence.track(pid3, config.topic, 2, %{name: "u1.2"})

    assert %{extra: "extra", metas: [%{name: "u1", phx_ref: _}, %{name: "u1.2", phx_ref: _}]} =
             MyPresence.get_by_key(config.topic, 1)

    assert MyPresence.get_by_key(config.topic, "another_key") == []
    assert MyPresence.get_by_key("another_topic", 2) == []
  end

  test "handle_diff broadcasts events with default fetched data",
       %{topic: topic} = config do
    pid = spawn(fn -> :timer.sleep(:infinity) end)
    Phoenix.PubSub.subscribe(config.pubsub, topic)
    start_supervised!({DefaultPresence, pubsub_server: config.pubsub})
    DefaultPresence.track(pid, topic, "u1", %{name: "u1"})

    assert_receive %Broadcast{
      topic: ^topic,
      event: "presence_diff",
      payload: %{
        joins: %{"u1" => %{metas: [%{name: "u1", phx_ref: u1_ref}]}},
        leaves: %{}
      }
    }

    assert %{"u1" => %{metas: [%{name: "u1", phx_ref: ^u1_ref}]}} = DefaultPresence.list(topic)

    Process.exit(pid, :kill)

    assert_receive %Broadcast{
      topic: ^topic,
      event: "presence_diff",
      payload: %{
        joins: %{},
        leaves: %{"u1" => %{metas: [%{name: "u1", phx_ref: ^u1_ref}]}}
      }
    }

    assert DefaultPresence.list(topic) == %{}
  end

  test "handle_diff broadcasts events with custom fetched data",
       %{topic: topic} = config do
    pid = spawn(fn -> :timer.sleep(:infinity) end)
    Phoenix.PubSub.subscribe(config.pubsub, topic)
    MyPresence.track(pid, topic, "u1", %{name: "u1"})

    assert_receive %Broadcast{
      topic: ^topic,
      event: "presence_diff",
      payload: %{
        joins: %{"u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: u1_ref}]}},
        leaves: %{}
      }
    }

    assert %{"u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: ^u1_ref}]}} =
             MyPresence.list(topic)

    Process.exit(pid, :kill)

    assert_receive %Broadcast{
      topic: ^topic,
      event: "presence_diff",
      payload: %{
        joins: %{},
        leaves: %{"u1" => %{extra: "extra", metas: [%{name: "u1", phx_ref: ^u1_ref}]}}
      }
    }

    assert MyPresence.list(topic) == %{}
  end

  test "untrack with pid", %{topic: topic} = config do
    Phoenix.PubSub.subscribe(config.pubsub, config.topic)
    MyPresence.track(self(), config.topic, "u1", %{})
    assert %{"u1" => %{metas: [%{}]}} = MyPresence.list(config.topic)
    assert MyPresence.untrack(self(), config.topic, "u1") == :ok

    assert_receive %Broadcast{
      topic: ^topic,
      event: "presence_diff",
      payload: %{
        joins: %{},
        leaves: %{"u1" => %{metas: [%{}]}}
      }
    }

    assert MyPresence.list(config.topic) == %{}
  end

  test "track and untrack with %Socket{}", %{topic: topic} = config do
    Phoenix.PubSub.subscribe(config.pubsub, topic)
    socket = %Phoenix.Socket{topic: topic, channel_pid: self()}
    MyPresence.track(socket, "u1", %{})
    assert %{"u1" => %{metas: [%{}]}} = MyPresence.list(topic)
    assert MyPresence.untrack(socket, "u1") == :ok

    assert_receive %Broadcast{
      topic: ^topic,
      event: "presence_diff",
      payload: %{
        joins: %{},
        leaves: %{"u1" => %{metas: [%{}]}}
      }
    }

    assert MyPresence.list(topic) == %{}
  end

  test "untrack with no tracked presence", config do
    assert MyPresence.untrack(self(), config.topic, "u1") == :ok
  end

  test "update sends join and leave diff", %{topic: topic} = config do
    Phoenix.PubSub.subscribe(config.pubsub, topic)
    MyPresence.track(self(), topic, "u1", %{name: "u1"})
    assert %{"u1" => %{metas: [%{name: "u1"}]}} = MyPresence.list(topic)
    assert {:ok, _} = MyPresence.update(self(), topic, "u1", %{name: "updated"})

    assert_receive %Broadcast{
      topic: ^topic,
      event: "presence_diff",
      payload: %{
        joins: %{"u1" => %{metas: [%{name: "updated"}]}},
        leaves: %{"u1" => %{metas: [%{name: "u1"}]}}
      }
    }

    assert %{"u1" => %{metas: [%{name: "updated"}]}} = MyPresence.list(topic)
  end

  test "update with no tracked presence" do
    assert MyPresence.update(self(), "topic", "u1", %{}) == {:error, :nopresence}
  end

  test "fetchers_pid" do
    assert is_list(MyPresence.fetchers_pids())
  end
end
