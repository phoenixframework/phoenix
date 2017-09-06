Phoenix Presence is a feature which allows you to register process information on a topic and replicate it transparently across a cluster. It's a combination of both a server-side and client-side library which makes it simple to implement. A simple use-case would be showing which users are currently online in an application.

Phoenix Presence is special for a number of reasons. It has no single point of failure, no single source of truth, relies entirely on the standard library with no operational dependencies and self heals. This is all handled with a conflict-free replicated data type (CRDT) protocol.

To get started with Presence we'll first need to generate a presence module. We can do this with the `mix phx.gen.presence` task:

```console
$ mix phx.gen.presence
* creating lib/hello_web/channels/presence.ex

Add your new module to your supervision tree,
in lib/hello/application.ex:

    children = [
      ...
      supervisor(HelloWeb.Presence, []),
    ]

You're all set! See the Phoenix.Presence docs for more details:
http://hexdocs.pm/phoenix/Phoenix.Presence.html
```

If we open up the `hello_web/channels/presence.ex` file, we will see the following line:

```elixir
  use Phoenix.Presence, otp_app: :hello,
                        pubsub_server: Hello.PubSub
```

This sets up the module for presence, defining the functions we require for tracking presences. As mentioned in the generator task, we should add this module to our supervision tree in
`application.ex`:

```elixir
children = [
  # ...
  supervisor(HelloWeb.Presence, [])
]
```

Next we will create a channel that Presence can communicate on. For this example we will create a `RoomChannel` ([see the channels guide for more details on this](channels.html)):

```console
$ mix phx.gen.channel Room
* creating lib/hello_web/channels/room_channel.ex
* creating test/hello_web/channels/room_channel_test.exs

Add the channel to your `lib/hello_web/channels/user_socket.ex` handler, for example:

    channel "room:lobby", HelloWeb.RoomChannel
```

and register it in `lib/hello_web/channels/user_socket.ex`:

```elixir
defmodule HelloWeb.UserSocket do
  use Phoenix.Socket

  channel "room:lobby", HelloWeb.RoomChannel
end
```

We also need to change our connect function to take a `user_id` from the params and assign it on the socket. In production you may want to use `Phoenix.Token` if you have real users that are authenticated.

```elixir
  def connect(params, socket) do
    {:ok, assign(socket, :user_id, params["user_id"])}
  end
```

Next, we will create the channel that we'll communicate presence over. After a user joins we can push the list of presences down the channel and then track the connection. We can also provide a map of additional information to track.

Note that we provide the `user_id` from the connection in order to uniquely identify the client. You can use whatever identifier you like, but you'll see how this is provided to the socket in the client-side example below.

To learn more about channels, read the [channel documentation in the guide](channels.html).

```elixir
defmodule HelloWeb.RoomChannel do
  use Phoenix.Channel
  alias HelloWeb.Presence

  def join("room:lobby", _params, socket) do
    send(self(), :after_join)
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

Finally we can use the client-side Presence library provided by Phoenix in order to manage the state and presence diffs that come down the socket. We listen for the initial `presence_state` event fired after joining to get the initial state and the later `presence_diff` events that contain joins and leaves.

We can use the included `Presence.syncState()` and `Presence.syncDiff()` methods to easily handle these events and sync our `presences` variable with the latest state. When we want to use the current presence state we can pass it through `Presence.list()` in order to get each presence individually.

When we want to iterate the users, we use the `Presences.list()` function which takes a presences object and a callback function. The callback will be called for each presence item with 2 arguments, the presence id and a list of metas (one for each presence for that presence id). We use this to display the users and the number of devices they are online with.

We can see presence working by adding the following to `assets/js/app.js`;

```javascript
import {Socket, Presence} from "phoenix"

let socket = new Socket("/socket", {
  params: { user_id: window.location.search.split("=")[1] }
})

function renderOnlineUsers(presences) {
  let response = "";

  Presence.list(presences, (id, {metas: [first, ...rest]}) => {
    let count = rest.length + 1
    response += `<br>${id} (count: ${count})</br>`
  });

  document.querySelector("main[role=main]").innerHTML = response;
}

socket.connect()

let presences = {}

let channel = socket.channel("room:lobby", {})

channel.on("presence_state", state => {
  presences = Presence.syncState(presences, state)
  renderOnlineUsers(presences)
})

channel.on("presence_diff", diff => {
  presences = Presence.syncDiff(presences, diff)
  renderOnlineUsers(presences)
})

channel.join()
```

We can ensure this is working by opening 3 browser tabs. If we navigate to http://localhost:4000/?name=Alice on two browser tabs and http://localhost:4000/?name=Bob then we should see:

```
Alice (count: 2)
Bob (count: 1)
```

If we close one of the Alice tabs, then the count should decrease to 1. If we close another tab, the user should disappear from the list entirely.
