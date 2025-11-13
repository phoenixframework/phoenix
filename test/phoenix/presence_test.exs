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

  defmodule MetasPresence do
    use Phoenix.Presence, otp_app: :phoenix

    def init(state), do: {:ok, state}

    def handle_metas(topic, diff, presences, state) do
      Phoenix.PubSub.local_broadcast(PresPub, topic, %{diff: diff, presences: presences})
      {:ok, state}
    end
  end

  defmodule MetasMissingInitPresence do
    use Phoenix.Presence, otp_app: :phoenix

    def init_presence do
      Phoenix.Presence.init({
        __MODULE__,
        __MODULE__.TaskSupervisor,
        PresPub,
        Phoenix.Channel.Server
      })
    end

    def handle_metas(_topic, _diff, _presences, _state) do
      raise ArgumentError, "should not be called due to missing init/1"
    end
  end

  defmodule CustomDispatcher do
    def dispatch(entries, from, message) do
      for {pid, _} <- entries, pid != from, do: send(pid, {:custom_dispatcher, message})

      :ok
    end
  end

  defmodule CustomDispatcherPresence do
    use Phoenix.Presence, otp_app: :phoenix, dispatcher: CustomDispatcher
  end

  Application.put_env(:phoenix, MyPresence, pubsub_server: PresPub)
  Application.put_env(:phoenix, MetasPresence, pubsub_server: PresPub)
  Application.put_env(:phoenix, CustomDispatcherPresence, pubsub_server: PresPub)

  setup_all do
    start_supervised!({Phoenix.PubSub, name: PresPub, pool_size: 1})
    start_supervised!(MyPresence)
    start_supervised!(MetasPresence)
    start_supervised!(CustomDispatcherPresence)
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

  test "handle_diff with custom dispatcher", %{topic: topic} = config do
    pid = spawn(fn -> :timer.sleep(:infinity) end)
    Phoenix.PubSub.subscribe(config.pubsub, topic)
    start_supervised!({DefaultPresence, pubsub_server: config.pubsub})
    CustomDispatcherPresence.track(pid, topic, "u1", %{name: "u1"})

    assert_receive {:custom_dispatcher,
                    %Broadcast{
                      topic: ^topic,
                      event: "presence_diff",
                      payload: %{
                        joins: %{"u1" => %{metas: [%{name: "u1", phx_ref: u1_ref}]}},
                        leaves: %{}
                      }
                    }}

    assert %{"u1" => %{metas: [%{name: "u1", phx_ref: ^u1_ref}]}} =
             CustomDispatcherPresence.list(topic)

    Process.exit(pid, :kill)

    assert_receive {:custom_dispatcher,
                    %Broadcast{
                      topic: ^topic,
                      event: "presence_diff",
                      payload: %{
                        joins: %{},
                        leaves: %{"u1" => %{metas: [%{name: "u1", phx_ref: ^u1_ref}]}}
                      }
                    }}

    assert CustomDispatcherPresence.list(topic) == %{}
  end

  test "untrack with pid", %{topic: topic} = config do
    Phoenix.PubSub.subscribe(config.pubsub, config.topic)
    MyPresence.track(self(), config.topic, "u1", %{})
    MyPresence.track(self(), config.topic, "u2", %{})

    assert %{
             "u1" => %{extra: "extra", metas: [%{}]},
             "u2" => %{extra: "extra", metas: [%{}]}
           } = MyPresence.list(config.topic)

    assert MyPresence.untrack(self(), config.topic, "u1") == :ok

    assert_receive %Broadcast{
      topic: ^topic,
      event: "presence_diff",
      payload: %{
        joins: %{},
        leaves: %{"u1" => %{metas: [%{}]}}
      }
    }

    assert %{"u2" => %{extra: "extra", metas: [%{}]}} = MyPresence.list(config.topic)
    assert map_size(MyPresence.list(config.topic)) == 1
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

  describe "Presence behaviour when handle_metas is defined" do
    test "raises when missing init/1" do
      assert_raise ArgumentError,
                   ~r|missing Phoenix.PresenceTest.MetasMissingInitPresence.init/1 callback for client state|,
                   fn ->
                     MetasMissingInitPresence.init_presence()
                   end
    end

    test "async_merge/2 creates new topic and metas",
         %{topic: topic} = config do
      Phoenix.PubSub.subscribe(config.pubsub, topic)
      MetasPresence.track(self(), topic, "u1", %{name: "u1"})

      assert_receive %{
        diff: %{
          joins: %{"u1" => %{metas: [%{name: "u1"}]}},
          leaves: %{}
        },
        presences: presences
      }

      assert %{"u1" => [%{name: "u1", phx_ref: _ref}]} = presences
    end

    test "async_merge/2 adds new presences to existing topic",
         %{topic: topic} = config do
      Phoenix.PubSub.subscribe(config.pubsub, topic)
      pid1 = spawn(fn -> :timer.sleep(:infinity) end)
      pid2 = spawn(fn -> :timer.sleep(:infinity) end)
      MetasPresence.track(pid1, topic, "u1", %{name: "u1"})
      MetasPresence.track(pid2, topic, "u2", %{name: "u2"})
      MetasPresence.track(self(), topic, "u3", %{name: "u3"})

      assert_receive %{
        diff: %{
          joins: %{"u3" => %{metas: [%{name: "u3"}]}},
          leaves: %{}
        },
        presences: presences
      }

      assert %{
               "u1" => [%{name: "u1", phx_ref: _u1_ref}],
               "u2" => [%{name: "u2", phx_ref: _u2_ref}],
               "u3" => [%{name: "u3", phx_ref: _u3_ref}]
             } = presences
    end

    test "async_merge/2 adds new metas to existing presence",
         %{topic: topic} = config do
      Phoenix.PubSub.subscribe(config.pubsub, topic)
      pid1 = spawn(fn -> :timer.sleep(:infinity) end)
      pid2 = spawn(fn -> :timer.sleep(:infinity) end)
      MetasPresence.track(pid1, topic, "u1", %{name: "u1.1"})
      MetasPresence.track(pid2, topic, "u1", %{name: "u1.2"})
      MetasPresence.track(self(), topic, "u1", %{name: "u1.3"})

      assert_receive %{
        diff: %{
          joins: %{"u1" => %{metas: [%{name: "u1.3"}]}},
          leaves: %{}
        },
        presences: presences
      }

      assert %{
               "u1" => [
                 %{name: "u1.1", phx_ref: _u1_1_ref},
                 %{name: "u1.2", phx_ref: _u1_2_ref},
                 %{name: "u1.3", phx_ref: _u1_3_ref}
               ]
             } = presences
    end

    test "async_merge/2 removes topic if it doesn't have presences",
         %{topic: topic} = config do
      Phoenix.PubSub.subscribe(config.pubsub, topic)
      pid1 = spawn(fn -> :timer.sleep(:infinity) end)
      pid2 = spawn(fn -> :timer.sleep(:infinity) end)

      MetasPresence.track(pid1, topic, "u1", %{name: "u1"})
      MetasPresence.track(pid2, topic, "u2", %{name: "u2"})
      MetasPresence.track(self(), topic, "u3", %{name: "u3"})

      MetasPresence.untrack(pid1, topic, "u1")
      MetasPresence.untrack(pid2, topic, "u2")
      MetasPresence.untrack(self(), topic, "u3")

      assert_receive %{
        diff: %{
          joins: %{},
          leaves: %{"u3" => %{metas: [%{name: "u3"}]}}
        },
        presences: presences
      }

      assert presences == %{}
    end

    test "async_merge/2 removes presence info if it only has one meta",
         %{topic: topic} = config do
      Phoenix.PubSub.subscribe(config.pubsub, topic)

      pid1 = spawn(fn -> :timer.sleep(:infinity) end)
      pid2 = spawn(fn -> :timer.sleep(:infinity) end)
      MetasPresence.track(pid1, topic, "u1", %{name: "u1"})
      MetasPresence.track(pid2, topic, "u2", %{name: "u2"})
      MetasPresence.track(self(), topic, "u3", %{name: "u3"})

      MetasPresence.untrack(self(), topic, "u3")

      assert_receive %{
        diff: %{
          joins: %{},
          leaves: %{"u3" => %{metas: [%{name: "u3"}]}}
        },
        presences: presences
      }

      assert map_size(presences) == 2

      assert %{
               "u1" => [%{name: "u1", phx_ref: _u1_ref}],
               "u2" => [%{name: "u2", phx_ref: _u2_ref}]
             } = presences
    end

    test "async_merge/2 removes metas when a presence left",
         %{topic: topic} = config do
      Phoenix.PubSub.subscribe(config.pubsub, topic)
      pid1 = spawn(fn -> :timer.sleep(:infinity) end)
      pid2 = spawn(fn -> :timer.sleep(:infinity) end)
      MetasPresence.track(pid1, topic, "u1", %{name: "u1.1"})
      MetasPresence.track(pid2, topic, "u1", %{name: "u1.2"})
      MetasPresence.track(self(), topic, "u1", %{name: "u1.3"})

      MetasPresence.untrack(self(), topic, "u1")

      assert_receive %{
        diff: %{
          joins: %{},
          leaves: %{"u1" => %{metas: [%{name: "u1.3"}]}}
        },
        presences: presences
      }

      assert %{"u1" => metas} = presences

      assert length(metas) == 2

      assert [
               %{name: "u1.1", phx_ref: _u1_1_ref},
               %{name: "u1.2", phx_ref: _u1_2_ref}
             ] = metas
    end
  end
end
