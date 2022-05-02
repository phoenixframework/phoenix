# Presence

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Channels guide](channels.html).

Phoenix Presence is a feature which allows you to register process information on a topic and replicate it transparently across a cluster. It's a combination of both a server-side and client-side library, which makes it simple to implement. A simple use-case would be showing which users are currently online in an application.

Phoenix Presence is special for a number of reasons. It has no single point of failure, no single source of truth, relies entirely on the standard library with no operational dependencies and self-heals.

## Setting up

We are going to use Presence to track which users are connected on the server and send updates to the client as users join and leave. We will deliver those updates via Phoenix Channels. Therefore, let's create a `RoomChannel`, as we did in the channels guides:

```console
$ mix phx.gen.channel Room
```

Follow the steps after the generator and you are ready to start tracking presence.

## The Presence generator

To get started with Presence, we'll first need to generate a presence module. We can do this with the `mix phx.gen.presence` task:

```console
$ mix phx.gen.presence
* creating lib/hello_web/channels/presence.ex

Add your new module to your supervision tree,
in lib/hello/application.ex:

    children = [
      ...
      HelloWeb.Presence,
    ]

You're all set! See the Phoenix.Presence docs for more details:
https://hexdocs.pm/phoenix/Phoenix.Presence.html
```

If we open up the `lib/hello_web/channels/presence.ex` file, we will see the following line:

```elixir
use Phoenix.Presence,
  otp_app: :hello,
  pubsub_server: Hello.PubSub
```

This sets up the module for presence, defining the functions we require for tracking presences. As mentioned in the generator task, we should add this module to our supervision tree in
`application.ex`:

```elixir
children = [
  ...
  HelloWeb.Presence,
]
```

Next, we will create the channel that we'll communicate presence over. After a user joins, we can push the list of presences down the channel and then track the connection. We can also provide a map of additional information to track.

```elixir
defmodule HelloWeb.RoomChannel do
  use Phoenix.Channel
  alias HelloWeb.Presence

  def join("room:lobby", %{"name" => name}, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :name, name)}
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.name, %{
        online_at: inspect(System.system_time(:second))
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end
end
```

Finally, we can use the client-side Presence library included in `phoenix.js` to manage the state and presence diffs that come down the socket. It listens for the `"presence_state"` and `"presence_diff"` events and provides a simple callback for you to handle the events as they happen, with the `onSync` callback.

The `onSync` callback allows you to easily react to presence state changes, which most often results in re-rendering an updated list of active users. You can use the `list` method to format and return each individual presence based on the needs of your application.

To iterate users, we use the `presences.list()` function which accepts a callback. The callback will be called for each presence item with 2 arguments, the presence id and a list of metas (one for each presence for that presence id). We use this to display the users and the number of devices they are online with.

We can see presence working by adding the following to `assets/js/app.js`:

```javascript
import {Socket, Presence} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})
let channel = socket.channel("room:lobby", {name: window.location.search.split("=")[1]})
let presence = new Presence(channel)

function renderOnlineUsers(presence) {
  let response = ""

  presence.list((id, {metas: [first, ...rest]}) => {
    let count = rest.length + 1
    response += `<br>${id} (count: ${count})</br>`
  })

  document.querySelector("main").innerHTML = response
}

socket.connect()

presence.onSync(() => renderOnlineUsers(presence))

channel.join()
```

We can ensure this is working by opening 3 browser tabs. If we navigate to <http://localhost:4000/?name=Alice> on two browser tabs and <http://localhost:4000/?name=Bob> then we should see:

```plaintext
Alice (count: 2)
Bob (count: 1)
```

If we close one of the Alice tabs, then the count should decrease to 1. If we close another tab, the user should disappear from the list entirely.

## Making it safe

In our initial implementation, we are passing the name of the user as part of the URL. However, in many systems, you want to allow only logged in users to access the presence functionality. To do so, you should set up token authentication, [as detailed in the token authentication section of the channels guide](channels.html#using-token-authentication).

With token authentication, you should access `socket.assigns.user_id`, set in `UserSocket`, instead of `socket.assigns.name` set from parameters.
