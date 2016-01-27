defmodule Phoenix.Presence do
  @moduledoc """
  TODO
  """
  alias Phoenix.Socket.Broadcast

  defmacro __using__(_) do
    quote do
      @task_supervisor Module.concat(__MODULE__, TaskSupervisor)
      def start_link(opts) do
        Phoenix.Presence.start_link(__MODULE__, @task_supervisor, opts)
      end

      def init(opts) do
        server = Keyword.fetch!(opts, :pubsub_server)
        {:ok, %{pubsub_server: server,
                node_name: Phoenix.PubSub.node_name(server),
                task_sup: @task_supervisor}}
      end

      def track(%Phoenix.Socket{} = socket, key, meta) do
        track(socket.channel_pid, socket.topic, key, meta)
      end
      def track(pid, topic, key, meta) do
        Phoenix.Tracker.track(__MODULE__, pid, topic, key, meta)
      end

      def fetch(_topic, presences), do: IO.inspect presences

      def list(topic) do
        topic
        |> fetch(Phoenix.Tracker.list(__MODULE__, topic))
        |> Phoenix.Presence.group_by_key()
      end

      def handle_join(topic, presence, state) do
        Phoenix.Presence.handle_join(__MODULE__,
          topic, presence, state.node_name, state.pubsub_server, state.task_sup
        )
        {:ok, state}
      end

      def handle_leave(topic, presence, state) do
        Phoenix.Presence.handle_leave(__MODULE__,
          topic, presence, state.node_name, state.pubsub_server, state.task_sup
        )
        {:ok, state}
      end

      defoverridable start_link: 1, init: 1, track: 4, fetch: 2, list: 1,
                     handle_join: 3, handle_leave: 3
    end
  end

  @doc """
  Starts the presence supervisor.
  """
  def start_link(module, task_supervisor, opts) do
    import Supervisor.Spec
    opts = Keyword.put(opts, :name, module)

    children = [
      supervisor(Task.Supervisor, [[name: task_supervisor]]),
      worker(Phoenix.Tracker, [module, opts, opts])
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  TODO
  """
  def handle_join(module, topic, presence, node_name, pubsub_server, sup_name) do
    Task.Supervisor.start_child(sup_name, fn ->
      presence_info = module.fetch(topic, [presence])
      msg = %Broadcast{topic: topic, event: "presence_join", payload: presence_info}
      Phoenix.PubSub.direct_broadcast!(node_name, pubsub_server, topic, msg)
    end)
  end

  @doc """
  TODO
  """
  def handle_leave(module, topic, presence, node_name, pubsub_server, sup_name) do
    Task.Supervisor.start_child(sup_name, fn ->
      presence_info = module.fetch(topic, [presence])
      msg = %Broadcast{topic: topic, event: "presence_leave", payload: presence_info}
      Phoenix.PubSub.direct_broadcast!(node_name, pubsub_server, topic, msg)
    end)
  end

  @doc """
  TODO
  """
  def group_by_key(presences) do
    presences
    |> Enum.group_by(fn %{key: key} -> key end)
    |> Enum.into(%{}, fn {key, grouped} ->
      metas = for %{meta: meta, ref: ref} <- grouped do
        %{meta: meta, ref: ref}
      end
      {key, metas}
    end)
  end
end
