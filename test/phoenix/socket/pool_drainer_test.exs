defmodule Phoenix.Socket.PoolDrainerTest do
  use ExUnit.Case, async: true

  alias Phoenix.Socket.{Broadcast, PoolDrainer, PoolSupervisor}

  Application.put_env(:phoenix, __MODULE__.Endpoint, server: false)

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :phoenix
  end

  setup_all do
    start_supervised!(Endpoint)
    :ok
  end

  # Each test drains its own pool, so tests cannot affect each other.
  setup do
    name = :"#{__MODULE__}.Pool#{System.unique_integer([:positive])}"
    start_supervised!({PoolSupervisor, {Endpoint, name, 2}})

    id = {__MODULE__, name}
    :telemetry.attach(id, [:phoenix, :socket_drain], &__MODULE__.handle_event/4, {self(), name})
    on_exit(fn -> :telemetry.detach(id) end)

    %{name: name}
  end

  def handle_event(_event, measurements, %{socket: name}, {parent, name}) do
    send(parent, {:drain, measurements})
  end

  def handle_event(_event, _measurements, _metadata, _config), do: :ok

  # Starts connections, drains them in batches and waits for the drainer to stop.
  defp drain(name, connections, opts) do
    parent = self()

    for key <- 1..connections//1 do
      connection = fn -> receive(do: (msg -> send(parent, {:drained, key, msg}))) end
      spec = %{id: key, start: {Task, :start_link, [connection]}, restart: :temporary}
      {:ok, _pid} = PoolSupervisor.start_child(%{endpoint: Endpoint, handler: name}, key, spec)
    end

    drainer = Keyword.merge([batch_interval: 1, log: false], opts)
    {:ok, pid} = PoolDrainer.start_link({Endpoint, name, drainer: drainer})
    GenServer.stop(pid)
  end

  describe "terminate/2" do
    test "notifies every connection that the socket is draining", %{name: name} do
      drain(name, 3, batch_size: 2)

      for key <- 1..3 do
        assert_receive {:drained, ^key, %Broadcast{event: "phx_drain"}}
      end
    end

    test "last batch is smaller when total is not a multiple of batch size", %{name: name} do
      drain(name, 5, batch_size: 2)

      assert_receive {:drain, %{index: 1, rounds: 3, count: 2, total: 5}}
      assert_receive {:drain, %{index: 2, rounds: 3, count: 2, total: 5}}
      assert_receive {:drain, %{index: 3, rounds: 3, count: 1, total: 5}}
      refute_receive {:drain, _}
    end

    test "reports no extra round when total is a multiple of batch size", %{name: name} do
      drain(name, 4, batch_size: 2)

      assert_receive {:drain, %{index: 1, rounds: 2, count: 2, total: 4}}
      assert_receive {:drain, %{index: 2, rounds: 2, count: 2, total: 4}}
      refute_receive {:drain, _}
    end

    test "does not wait for another interval after the last batch", %{name: name} do
      interval = 5_000
      started_at = System.monotonic_time(:millisecond)

      drain(name, 4, batch_size: 4, batch_interval: interval)

      assert System.monotonic_time(:millisecond) - started_at < interval
    end

    test "does nothing when there are no connections", %{name: name} do
      drain(name, 0, batch_size: 2)

      refute_receive {:drain, _}
    end
  end
end
