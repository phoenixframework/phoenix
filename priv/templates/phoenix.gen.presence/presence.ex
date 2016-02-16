defmodule <%= module %> do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](http://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.

  ## Usage

  Presences can be tracked in your channel after joining:

      defmodule <%= base %>.MyChannel do
        alias <%= base %>.Presence
        ...
        def join("some:topic", _params, socket) do
          send(self, :after_join)
          {:ok, assign(socket, :user_id, ...)}
        end

        def handle_info(:after_join, socket) do
          :ok = Presence.track(socket, socket.assigns.user_id, %{
            online_at: inspect(:os.timestamp())
          })
          push socket, "presences", Presence.list(socket)
          {:noreply, state}
        end
      end

  In the example above, `Presence.track` is used to register this
  channel's process as a presence for the socket's user ID, with
  a map of metadata. Next, the current presence list for
  the socket's topic is pushed to the client as a `"presences"` event.

  Finally, a diff of presence join and leave events will be sent to the
  client as they happen in real-time with the "presence_diff" event.
  See `Phoenix.Presence.list/2` for details on the presence datastructure.


  ## Fetching Presence Information

  Presence metadata should be minimized and used for ephemeral state
  like a users "online" or "away" status. Somtimes you'll want to
  extend the metadata with information from the database, such as a user's
  name or proifle information. You can do this by overriding `fetch/2`:

      def fetch(_topic, entries) do
        query =
          from u in User,
            where: u.id in ^Map.keys(entries),
            select: {u.id, u}

        users = query |> Repo.all |> Enum.into(%{})

        for {key, %{metas: metas}} <- entries, into: %{} do
          {key, %{metas: metas, user: users[key]}}
        end
      end

  The function above fetches all users from the database who
  have registered presences for the given topic. The fetched
  information is then extended with a `:user` key of the user's
  information, while maintaining the required `:metas` field from the
  original presence data.
  """
  use Phoenix.Presence, otp_app: <%= inspect otp_app %>
end
