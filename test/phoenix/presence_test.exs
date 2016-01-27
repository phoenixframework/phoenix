defmodule Phoenix.PresenceTest do
  use ExUnit.Case, async: true

  defmodule DefaultPresence do
    use Phoenix.Presence
  end

  defmodule MyPresence do
    use Phoenix.Presence

    def fetch(_topic, presences) do
      for %{key: user_id, meta: meta, ref: ref} <- presences do
        %{key: user_id, meta: %{name: String.upcase(meta.name)}, ref: ref}
      end
    end
  end

  setup_all do
    {:ok, _} = Phoenix.PubSub.PG2.start_link(PresPub, pool_size: 1)
    assert {:ok, _pid} = MyPresence.start_link(pubsub_server: PresPub)
    {:ok, pubsub: PresPub}
  end

  test "default fetch/2 returns pass-through data" do
    presences = [%{key: "key", meta: %{}, ref: "ref"}]
    assert DefaultPresence.fetch("topic", presences) == presences
  end

  test "list/1 lists presences from tracker" do
    assert MyPresence.list("topic") == %{}
    assert MyPresence.track(self(), "topic", "u1", %{name: "u1"}) == :ok
    assert %{"u1" => [%{meta: %{name: "U1"}, ref: _}]} = MyPresence.list("topic")
  end
end
