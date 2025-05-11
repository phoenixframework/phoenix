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

## Usage With Channels and JavaScript

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

let socket = new Socket("/socket", {authToken: window.userToken})
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

### Making it safe

In our initial implementation, we are passing the name of the user as part of the URL. However, in many systems, you want to allow only logged in users to access the presence functionality. To do so, you should set up token authentication, [as detailed in the token authentication section of the channels guide](channels.html#using-token-authentication).

With token authentication, you should access `socket.assigns.user_id`, set in `UserSocket`, instead of `socket.assigns.name` set from parameters.

## Usage With LiveView

Whilst Phoenix does ship with a JavaScript API for dealing with presence, it is also possible to extend the `HelloWeb.Presence` module to support [LiveView](https://hexdocs.pm/phoenix_live_view).

One thing to keep in mind when dealing with LiveView, is that each LiveView is a stateful process, so if we keep the presence state in the LiveView, each LiveView process will contain the full list of online users in memory. Instead, we can keep track of the online users within the `Presence` process, and pass separate events to the LiveView, which can use a stream to update the online list.

To start with, we need to update the `lib/hello_web/channels/presence.ex` file to add some optional callbacks to the `HelloWeb.Presence` module.

Firstly, we add the `init/1` callback. This allows us to keep track of the presence state within the process.

```elixir
  def init(_opts) do
    {:ok, %{}}
  end
```

The presence module also allows a `fetch/2` callback, this allows the data fetched from the presence to be modified, allowing us to define the shape of the response. In this case we are adding an `id` and a `user` map.

```elixir
  def fetch(_topic, presences) do
    for {key, %{metas: [meta | metas]}} <- presences, into: %{} do
      # user can be populated here from the database here we populate
      # the name for demonstration purposes
      {key, %{metas: [meta | metas], id: meta.id, user: %{name: meta.id}}}
    end
  end
```

The final thing to add is the `handle_metas/4` callback. This callback updates the state that we keep track of in `HelloWeb.Presence` based on the user leaves and joins.

```elixir
  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    for {user_id, presence} <- joins do
      user_data = %{id: user_id, user: presence.user, metas: Map.fetch!(presences, user_id)}
      msg = {__MODULE__, {:join, user_data}}
      Phoenix.PubSub.local_broadcast(Hello.PubSub, "proxy:#{topic}", msg)
    end

    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{id: user_id, user: presence.user, metas: metas}
      msg = {__MODULE__, {:leave, user_data}}
      Phoenix.PubSub.local_broadcast(Hello.PubSub, "proxy:#{topic}", msg)
    end

    {:ok, state}
  end
```

You can see that we are broadcasting events for the joins and leaves. These will be listened to by the LiveView process. You'll also see that we use "proxy" channel when broadcasting the joins and leaves. This is because we don't want our LiveView process to receive the presence events directly. We can add a few helper functions so that this particular implementation detail is abstracted from the LiveView module.

```elixir
  def list_online_users(), do: list("online_users") |> Enum.map(fn {_id, presence} -> presence end)

  def track_user(name, params), do: track(self(), "online_users", name, params)

  def subscribe(), do: Phoenix.PubSub.subscribe(Hello.PubSub, "proxy:online_users")
```

Now that we have our presence module set up and broadcasting events, we can create a LiveView. Create a new file `lib/hello_web/live/online/index.ex` with the following contents:

```elixir
defmodule HelloWeb.OnlineLive do
  use HelloWeb, :live_view

  def mount(params, _session, socket) do
    socket = stream(socket, :presences, [])
    socket =
    if connected?(socket) do
      HelloWeb.Presence.track_user(params["name"], %{id: params["name"]})
      HelloWeb.Presence.subscribe()
      stream(socket, :presences, HelloWeb.Presence.list_online_users())
    else
       socket
    end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <ul id="online_users" phx-update="stream">
      <li :for={{dom_id, %{id: id, metas: metas}} <- @streams.presences} id={dom_id}>{id} ({length(metas)})</li>
    </ul>
    """
  end

  def handle_info({HelloWeb.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  def handle_info({HelloWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end
end
```

If we add this route to the `lib/hello_web/router.ex`:

```elixir
    live "/online/:name", OnlineLive, :index
```

Then we can navigate to http://localhost:4000/online/Alice in one tab, and http://localhost:4000/online/Bob in another, you'll see that the presences are tracked, along with the number of presences per user. Opening and closing tabs with various users will update the presence list in real-time.
