defmodule Phoenix.Presence do
  @moduledoc """
  Provides Presence tracking to processes and channels.

  This behaviour provides presence features such as fetching
  presences for a given topic, as well as handling diffs of
  join and leave events as they occur in real-time. Using this
  module defines a supervisor and a module that implements the
  `Phoenix.Tracker` behaviour that uses `Phoenix.PubSub` to
  broadcast presence updates.

  In case you want to use only a subset of the functionality
  provided by `Phoenix.Presence`, such as tracking processes
  but without broadcasting updates, we recommend that you look
  at the `Phoenix.Tracker` functionality from the `phoenix_pubsub`
  project.

  ## Example Usage

  Start by defining a presence module within your application
  which uses `Phoenix.Presence` and provide the `:otp_app` which
  holds your configuration, as well as the `:pubsub_server`.

      defmodule MyAppWeb.Presence do
        use Phoenix.Presence,
          otp_app: :my_app,
          pubsub_server: MyApp.PubSub
      end

  The `:pubsub_server` must point to an existing pubsub server
  running in your application, which is included by default as
  `MyApp.PubSub` for new applications.

  Next, add the new supervisor to your supervision tree in
  `lib/my_app/application.ex`. It must be after the PubSub child
  and before the endpoint:

      children = [
        ...
        {Phoenix.PubSub, name: MyApp.PubSub},
        MyAppWeb.Presence,
        MyAppWeb.Endpoint
      ]

  Once added, presences can be tracked in your channel after joining:

      defmodule MyAppWeb.MyChannel do
        use MyAppWeb, :channel
        alias MyAppWeb.Presence

        def join("some:topic", _params, socket) do
          send(self(), :after_join)
          {:ok, assign(socket, :user_id, ...)}
        end

        def handle_info(:after_join, socket) do
          {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
            online_at: inspect(System.system_time(:second))
          })

          push(socket, "presence_state", Presence.list(socket))
          {:noreply, socket}
        end
      end

  In the example above, `Presence.track` is used to register this channel's process as a
  presence for the socket's user ID, with a map of metadata.
  Next, the current presence information for
  the socket's topic is pushed to the client as a `"presence_state"` event.

  Finally, a diff of presence join and leave events will be sent to the
  client as they happen in real-time with the "presence_diff" event.
  The diff structure will be a map of `:joins` and `:leaves` of the form:

      %{
        joins: %{"123" => %{metas: [%{status: "away", phx_ref: ...}]}},
        leaves: %{"456" => %{metas: [%{status: "online", phx_ref: ...}]}}
      },

  See `c:list/1` for more information on the presence data structure.

  ## Fetching Presence Information

  Presence metadata should be minimized and used to store small,
  ephemeral state, such as a user's "online" or "away" status.
  More detailed information, such as user details that need to be fetched
  from the database, can be achieved by overriding the `c:fetch/2` function.

  The `c:fetch/2` callback is triggered when using `c:list/1` and on
  every update, and it serves as a mechanism to fetch presence information
  a single time, before broadcasting the information to all channel subscribers.
  This prevents N query problems and gives you a single place to group
  isolated data fetching to extend presence metadata.

  The function must return a map of data matching the outlined Presence
  data structure, including the `:metas` key, but can extend the map of
  information to include any additional information. For example:

      def fetch(_topic, presences) do
        users = presences |> Map.keys() |> Accounts.get_users_map()

        for {key, %{metas: metas}} <- presences, into: %{} do
          {key, %{metas: metas, user: users[String.to_integer(key)]}}
        end
      end

  Where `Account.get_users_map/1` could be implemented like:

      def get_users_map(ids) do
        query =
          from u in User,
            where: u.id in ^ids,
            select: {u.id, u}

        query |> Repo.all() |> Enum.into(%{})
      end

  The `fetch/2` function above fetches all users from the database who
  have registered presences for the given topic. The presences
  information is then extended with a `:user` key of the user's
  information, while maintaining the required `:metas` field from the
  original presence data.

  ## Using Elixir as a Presence Client

  Presence is great for external clients, such as JavaScript applications, but
  it can also be used from an Elixir client process to keep track of presence
  changes as they happen on the server. This can be accomplished by implementing
  the optional [`init/1`](`c:init/1`) and [`handle_metas/4`](`c:handle_metas/4`)
  callbacks on your presence module. For example, the following callback
  receives presence metadata changes, and broadcasts to other Elixir processes
  about users joining and leaving:

      defmodule MyApp.Presence do
        use Phoenix.Presence,
          otp_app: :my_app,
          pubsub_server: MyApp.PubSub

        def init(_opts) do
          {:ok, %{}} # user-land state
        end

        def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
          # fetch existing presence information for the joined users and broadcast the
          # event to all subscribers
          for {user_id, presence} <- joins do
            user_data = %{user: presence.user, metas: Map.fetch!(presences, user_id)}
            msg = {MyApp.PresenceClient, {:join, user_data}}
            Phoenix.PubSub.local_broadcast(MyApp.PubSub, topic, msg)
          end

          # fetch existing presence information for the left users and broadcast the
          # event to all subscribers
          for {user_id, presence} <- leaves do
            metas =
              case Map.fetch(presences, user_id) do
                {:ok, presence_metas} -> presence_metas
                :error -> []
              end

            user_data = %{user: presence.user, metas: metas}
            msg = {MyApp.PresenceClient, {:leave, user_data}}
            Phoenix.PubSub.local_broadcast(MyApp.PubSub, topic, msg)
          end

          {:ok, state}
        end
      end

  The `handle_metas/4` callback receives the topic, presence diff, current presences
  for the topic with their metadata, and any user-land state accumulated from init and
  subsequent `handle_metas/4` calls. In our example implementation, we walk the `:joins` and
  `:leaves` in the diff, and populate a complete presence from our known presence information.
  Then we broadcast to the local node subscribers about user joins and leaves.

  ## Testing with Presence

  Every time the `fetch` callback is invoked, it is done from a separate
  process. Given those processes run asynchronously, it is often necessary
  to guarantee they have been shutdown at the end of every test. This can
  be done by using ExUnit's `on_exit` hook plus `fetchers_pids` function:

      on_exit(fn ->
        for pid <- MyAppWeb.Presence.fetchers_pids() do
          ref = Process.monitor(pid)
          assert_receive {:DOWN, ^ref, _, _, _}, 1000
        end
      end)

  """

  @type presences :: %{String.t() => %{metas: [map()]}}
  @type presence :: %{key: String.t(), meta: map()}
  @type topic :: String.t()

  @doc """
  Track a channel's process as a presence.

  Tracked presences are grouped by `key`, cast as a string. For example, to
  group each user's channels together, use user IDs as keys. Each presence can
  be associated with a map of metadata to store small, ephemeral state, such as
  a user's online status. To store detailed information, see `c:fetch/2`.

  ## Example

      alias MyApp.Presence
      def handle_info(:after_join, socket) do
        {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
          online_at: inspect(System.system_time(:second))
        })
        {:noreply, socket}
      end

  """
  @callback track(socket :: Phoenix.Socket.t(), key :: String.t(), meta :: map()) ::
              {:ok, ref :: binary()}
              | {:error, reason :: term()}

  @doc """
  Track an arbitrary process as a presence.

  Same with `track/3`, except track any process by `topic` and `key`.
  """
  @callback track(pid, topic, key :: String.t(), meta :: map()) ::
              {:ok, ref :: binary()}
              | {:error, reason :: term()}

  @doc """
  Stop tracking a channel's process.
  """
  @callback untrack(socket :: Phoenix.Socket.t(), key :: String.t()) :: :ok

  @doc """
  Stop tracking a process.
  """
  @callback untrack(pid, topic, key :: String.t()) :: :ok

  @doc """
  Update a channel presence's metadata.

  Replace a presence's metadata by passing a new map or a function that takes
  the current map and returns a new one.
  """
  @callback update(
              socket :: Phoenix.Socket.t(),
              key :: String.t(),
              meta :: map() | (map() -> map())
            ) ::
              {:ok, ref :: binary()}
              | {:error, reason :: term()}

  @doc """
  Update a process presence's metadata.

  Same as `update/3`, but with an arbitrary process.
  """
  @callback update(pid, topic, key :: String.t(), meta :: map() | (map() -> map())) ::
              {:ok, ref :: binary()}
              | {:error, reason :: term()}

  @doc """
  Returns presences for a socket/topic.

  ## Presence data structure

  The presence information is returned as a map with presences grouped
  by key, cast as a string, and accumulated metadata, with the following form:

      %{key => %{metas: [%{phx_ref: ..., ...}, ...]}}

  For example, imagine a user with id `123` online from two
  different devices, as well as a user with id `456` online from
  just one device. The following presence information might be returned:

      %{"123" => %{metas: [%{status: "away", phx_ref: ...},
                           %{status: "online", phx_ref: ...}]},
        "456" => %{metas: [%{status: "online", phx_ref: ...}]}}

  The keys of the map will usually point to a resource ID. The value
  will contain a map with a `:metas` key containing a list of metadata
  for each resource. Additionally, every metadata entry will contain a
  `:phx_ref` key which can be used to uniquely identify metadata for a
  given key. In the event that the metadata was previously updated,
  a `:phx_ref_prev` key will be present containing the previous
  `:phx_ref` value.
  """
  @callback list(Phoenix.Socket.t() | topic) :: presences

  @doc """
  Returns the map of presence metadata for a socket/topic-key pair.

  ## Examples

  Uses the same data format as each presence in `c:list/1`, but only
  returns metadata for the presences under a topic and key pair. For example,
  a user with key `"user1"`, connected to the same chat room `"room:1"` from two
  devices, could return:

      iex> MyPresence.get_by_key("room:1", "user1")
      [%{name: "User 1", metas: [%{device: "Desktop"}, %{device: "Mobile"}]}]

  Like `c:list/1`, the presence metadata is passed to the `fetch`
  callback of your presence module to fetch any additional information.
  """
  @callback get_by_key(Phoenix.Socket.t() | topic, key :: String.t()) :: [presence]

  @doc """
  Extend presence information with additional data.

  When `c:list/1` is used to list all presences of the given `topic`, this
  callback is triggered once to modify the result before it is broadcasted to
  all channel subscribers. This avoids N query problems and provides a single
  place to extend presence metadata. You must return a map of data matching the
  original result, including the `:metas` key, but can extend the map to include
  any additional information.

  The default implementation simply passes `presences` through unchanged.

  ## Example

      def fetch(_topic, presences) do
        query =
          from u in User,
            where: u.id in ^Map.keys(presences),
            select: {u.id, u}

        users = query |> Repo.all() |> Enum.into(%{})
        for {key, %{metas: metas}} <- presences, into: %{} do
          {key, %{metas: metas, user: users[key]}}
        end
      end

  """
  @callback fetch(topic, presences) :: presences

  @doc """
  Initializes the presence client state.

  Invoked when your presence module starts, allows dynamically
  providing initial state for handling presence metadata.
  """
  @callback init(state :: term) :: {:ok, new_state :: term}

  @doc """
  Receives presence metadata changes.
  """
  @callback handle_metas(topic :: String.t(), diff :: map(), presences :: map(), state :: term) ::
              {:ok, term}

  @optional_callbacks init: 1, handle_metas: 4

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Phoenix.Presence
      @opts opts
      @task_supervisor Module.concat(__MODULE__, "TaskSupervisor")

      _ = opts[:otp_app] || raise "use Phoenix.Presence expects :otp_app to be given"

      # User defined
      def fetch(_topic, presences), do: presences
      defoverridable fetch: 2

      # Private

      def child_spec(opts) do
        opts = Keyword.merge(@opts, opts)

        %{
          id: __MODULE__,
          start: {Phoenix.Presence, :start_link, [__MODULE__, @task_supervisor, opts]},
          type: :supervisor
        }
      end

      # API

      def track(%Phoenix.Socket{} = socket, key, meta) do
        track(socket.channel_pid, socket.topic, key, meta)
      end

      def track(pid, topic, key, meta) do
        Phoenix.Tracker.track(__MODULE__, pid, topic, key, meta)
      end

      def untrack(%Phoenix.Socket{} = socket, key) do
        untrack(socket.channel_pid, socket.topic, key)
      end

      def untrack(pid, topic, key) do
        Phoenix.Tracker.untrack(__MODULE__, pid, topic, key)
      end

      def update(%Phoenix.Socket{} = socket, key, meta) do
        update(socket.channel_pid, socket.topic, key, meta)
      end

      def update(pid, topic, key, meta) do
        Phoenix.Tracker.update(__MODULE__, pid, topic, key, meta)
      end

      def list(%Phoenix.Socket{topic: topic}), do: list(topic)
      def list(topic), do: Phoenix.Presence.list(__MODULE__, topic)

      def get_by_key(%Phoenix.Socket{topic: topic}, key), do: get_by_key(topic, key)
      def get_by_key(topic, key), do: Phoenix.Presence.get_by_key(__MODULE__, topic, key)

      def fetchers_pids(), do: Task.Supervisor.children(@task_supervisor)
    end
  end

  defmodule Tracker do
    @moduledoc false
    use Phoenix.Tracker

    def start_link({module, task_supervisor, opts}) do
      pubsub_server =
        opts[:pubsub_server] || raise "use Phoenix.Presence expects :pubsub_server to be given"

      Phoenix.Tracker.start_link(
        __MODULE__,
        {module, task_supervisor, pubsub_server},
        opts
      )
    end

    def init(state), do: Phoenix.Presence.init(state)

    def handle_diff(diff, state), do: Phoenix.Presence.handle_diff(diff, state)

    def handle_info(msg, state),
      do: Phoenix.Presence.handle_info(msg, state)
  end

  @doc false
  def start_link(module, task_supervisor, opts) do
    otp_app = opts[:otp_app]

    opts =
      opts
      |> Keyword.merge(Application.get_env(otp_app, module, []))
      |> Keyword.put(:name, module)

    children = [
      {Task.Supervisor, name: task_supervisor},
      {Tracker, {module, task_supervisor, opts}}
    ]

    sup_opts = [
      strategy: :rest_for_one,
      name: Module.concat(module, "Supervisor")
    ]

    Supervisor.start_link(children, sup_opts)
  end

  @doc false
  def init({module, task_supervisor, pubsub_server}) do
    state = %{
      module: module,
      task_supervisor: task_supervisor,
      pubsub_server: pubsub_server,
      topics: %{},
      tasks: :queue.new(),
      current_task: nil,
      client_state: nil
    }

    client_state =
      if function_exported?(module, :handle_metas, 4) do
        unless function_exported?(module, :init, 1) do
          raise ArgumentError, """
          missing #{inspect(module)}.init/1 callback for client state

          When you implement the handle_metas/4 callback, you must also
          implement init/1. For example, add the following to
          #{inspect(module)}:

          def init(_opts), do: {:ok, %{}}

          """
        end

        case module.init(%{}) do
          {:ok, client_state} ->
            client_state

          other ->
            raise ArgumentError, """
            expected #{inspect(module)}.init/1 to return {:ok, state}, got: #{inspect(other)}
            """
        end
      end

    {:ok, %{state | client_state: client_state}}
  end

  @doc false
  def handle_diff(diff, state) do
    {:ok, async_merge(state, diff)}
  end

  @doc false
  def handle_info({task_ref, {:phoenix, ref, computed_diffs}}, state) do
    %{current_task: current_task} = state
    {^ref, %Task{ref: ^task_ref} = task} = current_task
    Task.shutdown(task)

    Enum.each(computed_diffs, fn {topic, presence_diff} ->
      Phoenix.Channel.Server.local_broadcast(
        state.pubsub_server,
        topic,
        "presence_diff",
        presence_diff
      )
    end)

    new_state =
      if function_exported?(state.module, :handle_metas, 4) do
        do_handle_metas(state, computed_diffs)
      else
        state
      end

    {:noreply, next_task(new_state)}
  end

  @doc false
  def list(module, topic) do
    grouped =
      module
      |> Phoenix.Tracker.list(topic)
      |> group()

    module.fetch(topic, grouped)
  end

  @doc false
  def get_by_key(module, topic, key) do
    string_key = to_string(key)

    case Phoenix.Tracker.get_by_key(module, topic, key) do
      [] ->
        []

      [_ | _] = pid_metas ->
        metas = Enum.map(pid_metas, fn {_pid, meta} -> meta end)
        %{^string_key => fetched_metas} = module.fetch(topic, %{string_key => %{metas: metas}})
        fetched_metas
    end
  end

  @doc false
  def group(presences) do
    presences
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn {key, meta}, acc ->
      Map.update(acc, to_string(key), %{metas: [meta]}, fn %{metas: metas} ->
        %{metas: [meta | metas]}
      end)
    end)
  end

  defp send_continue(%Task{} = task, ref), do: send(task.pid, {ref, :continue})

  defp next_task(state) do
    case :queue.out(state.tasks) do
      {{:value, {ref, %Task{} = next}}, remaining_tasks} ->
        send_continue(next, ref)
        %{state | current_task: {ref, next}, tasks: remaining_tasks}

      {:empty, _} ->
        %{state | current_task: nil, tasks: :queue.new()}
    end
  end

  defp do_handle_metas(state, computed_diffs) do
    Enum.reduce(computed_diffs, state, fn {topic, presence_diff}, acc ->
      updated_topics = merge_diff(acc.topics, topic, presence_diff)

      topic_presences =
        case Map.fetch(updated_topics, topic) do
          {:ok, presences} -> presences
          :error -> %{}
        end

      case acc.module.handle_metas(topic, presence_diff, topic_presences, acc.client_state) do
        {:ok, updated_client_state} ->
          %{acc | topics: updated_topics, client_state: updated_client_state}

        other ->
          raise ArgumentError, """
          expected #{inspect(acc.module)}.handle_metas/4 to return {:ok, new_state}.

            got: #{inspect(other)}
          """
      end
    end)
  end

  defp async_merge(state, diff) do
    %{module: module} = state
    ref = make_ref()

    new_task =
      Task.Supervisor.async(state.task_supervisor, fn ->
        computed_diffs =
          Enum.map(diff, fn {topic, {joins, leaves}} ->
            joins = module.fetch(topic, Phoenix.Presence.group(joins))
            leaves = module.fetch(topic, Phoenix.Presence.group(leaves))
            {topic, %{joins: joins, leaves: leaves}}
          end)

        receive do
          {^ref, :continue} -> {:phoenix, ref, computed_diffs}
        end
      end)

    if state.current_task do
      %{state | tasks: :queue.in({ref, new_task}, state.tasks)}
    else
      send_continue(new_task, ref)
      %{state | current_task: {ref, new_task}}
    end
  end

  defp merge_diff(topics, topic, %{leaves: leaves, joins: joins} = _diff) do
    # add new topic if needed
    updated_topics =
      if Map.has_key?(topics, topic) do
        topics
      else
        add_new_topic(topics, topic)
      end

    # merge diff into topics
    {updated_topics, _topic} = Enum.reduce(joins, {updated_topics, topic}, &handle_join/2)
    {updated_topics, _topic} = Enum.reduce(leaves, {updated_topics, topic}, &handle_leave/2)

    # if no more presences for given topic, remove topic
    if topic_presences_count(updated_topics, topic) == 0 do
      remove_topic(updated_topics, topic)
    else
      updated_topics
    end
  end

  defp handle_join({joined_key, presence}, {topics, topic}) do
    joined_metas = Map.get(presence, :metas, [])
    {add_new_presence_or_metas(topics, topic, joined_key, joined_metas), topic}
  end

  defp handle_leave({left_key, presence}, {topics, topic}) do
    {remove_presence_or_metas(topics, topic, left_key, presence), topic}
  end

  defp add_new_presence_or_metas(
         topics,
         topic,
         key,
         new_metas
       ) do
    topic_presences = topics[topic]

    updated_topic =
      case Map.fetch(topic_presences, key) do
        # existing presence, add new metas
        {:ok, existing_metas} ->
          remaining_metas = new_metas -- existing_metas
          updated_metas = existing_metas ++ remaining_metas
          Map.put(topic_presences, key, updated_metas)

        # there are no presences for that key
        :error ->
          Map.put_new(topic_presences, key, new_metas)
      end

    Map.put(topics, topic, updated_topic)
  end

  defp remove_presence_or_metas(
         topics,
         topic,
         key,
         deleted_metas
       ) do
    topic_presences = topics[topic]
    presence_metas = Map.get(topic_presences, key, [])
    remaining_metas = presence_metas -- Map.get(deleted_metas, :metas, [])

    updated_topic =
      case remaining_metas do
        [] -> Map.delete(topic_presences, key)
        _ -> Map.put(topic_presences, key, remaining_metas)
      end

    Map.put(topics, topic, updated_topic)
  end

  defp add_new_topic(topics, topic) do
    Map.put_new(topics, topic, %{})
  end

  defp remove_topic(topics, topic) do
    Map.delete(topics, topic)
  end

  defp topic_presences_count(topics, topic) do
    map_size(topics[topic])
  end
end
