Phoenix Presence is a feature which allows you to register process information on a topic and replicate it transparently across a cluster. It's a combination of both a server-side and client-side library which makes it simple to implement. A simple use-case would be showing which users are currently online in an application.

Phoenix Presence is special for a number of reasons. It has no single point of failure, no single source of truth, relies entirely on the standard library with no operational dependencies and self heals. This is all handled with a conflict-free replicated data type (CRDT) protocol.

To get started with Presence you'll need to create a channel that it can communicate on. For this example we will create a `RoomChannel` and register it in our `UserSocket`.

```elixir
defmodule HelloPhoenix.UserSocket do
  use Phoenix.Socket

  channel "room:lobby", HelloPhoenix.RoomChannel

  #
end
```

Next, create the channel that you'll communicate presence over. After a user joins you can push the list of presences down the channel and then track the connection. You can also provide a map of additional information to track.

Note that we provide the `user_id` from the connection in order to uniquely identify the client. You can use whatever identifier you like, but you'll see how this is provided to the socket in the client-side example below.

To learn more about channels, read the Channel documentation in the guide.

```elixir
defmodule HelloPhoenix.RoomChannel do
  use HelloPhoenix.Web, :channel
  alias HelloPhoenix.Presence

  def join("room:lobby", _params, socket) do
    send(self, :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    push socket, "presence_state", Presence.list(socket)
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:seconds))
    })
    {:noreply, socket}
  end
end
```

Finally you'll use the client-side Presence library provided by Phoenix in order to manage the state and presence diffs that come down the socket. You'll listen for the initial `presence_state` event fired after joining to get the initial state and the later `presence_diff` events that contain joins and leaves.

You can use the included `Presence.syncState()` and `Presence.syncDiff()` methods to easily handle these events and sync your `presences` variable with the latest state. When you want to use the current presence state you can pass it through `Presence.list()` in order to get each presence individually.

Note that we are passing the `user_id` parameter to the socket which is used to identify the user. You will probably want to look into using Phoenix's token authentication to securely determine the current user.

```javascript
imoprt {Socket, Presence} from "phoenix"

let socket = new Socket("/socket", {
  params: { user_id: window.userId }
})

socket.connect()

let presences = {}

let channel = socket.channel("room:lobby", {})

channel.on("presence_state", state => {
  presences = Presence.syncState(presences, state)

  Presence.list(presences)
    .map(user => console.log(user))
})

channel.on("presence_diff", diff => {
  presences = Presence.syncDiff(presences)

  Presence.list(presences)
    .map(user => console.log(user))
})

channel.join()
```
