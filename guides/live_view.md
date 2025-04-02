# LiveView

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [request life-cycle guide](request_lifecycle.html).

We've already seen how the typical request lifecycle in Phoenix works: a request is matched in the router, a controller handles the request and turns to a view to return a response in the correct format. But what if we want to build interactive pages? In a typical server rendered application, changing the content of the page either needs a form submission rendering the new page, or moving application logic to the client (JavaScript frameworks like jQuery, React, Vue, etc.) and building an API interface for the client to talk to.

Phoenix LiveView offers a different approach, keeping all the state on the server while providing rich, real-time user experiences with server-rendered HTML. It's an alternative to client-side JavaScript frameworks that allows you to build dynamic, interactive applications with minimal JavaScript code on the client.

## What is a LiveView?

LiveViews are processes that receive events, update their state, and render updates to a page as diffs.

The LiveView programming model is declarative: instead of saying "once event X happens, change Y on the page", events in LiveView are regular messages which may cause changes to the state. Once the state changes, the LiveView will re-render the relevant parts of its HTML template and push it to the browser, which updates the page in the most efficient manner.

LiveView state is nothing more than functional and immutable Elixir data structures. The events are either internal application messages (usually emitted by `Phoenix.PubSub`) or sent by the client/browser.

Every LiveView is first rendered statically as part of a regular HTTP request, which provides quick times for "First Meaningful Paint", in addition to helping search and indexing engines. A persistent connection is then established between the client and server to exchange events and changes to the page. This allows LiveView applications to react faster to user events as there is less work to be done and less data to be sent compared to stateless requests that have to authenticate, decode, load, and encode data on every request. You can think of LiveView as "diffs over the wire".

## LiveView vs Controller + View

While Phoenix controllers and LiveViews serve similar purposes in handling user interactions, they operate very differently:

### Controller + View

- Controllers handle each HTTP request-response pair as separate transactions
- Each page load or form submission requires a full request/response cycle
- Controllers are stateless, with data stored externally (database, session)
- Views are separate modules that render templates with the data from controllers
- Page updates and dynamic interactions require either full page reloads or custom client-side JavaScript code

### LiveView approach

- Initial page load uses the regular request lifecycle, but then establishes a bidirectional connection using [Phoenix Channels](channels.md)
- A LiveView process maintains state throughout user interaction
- State changes automatically trigger re-renders of only the changed parts of the page
- Events flow through the persistent connection instead of separate HTTP requests
- Minimal JavaScript is required for interactive features

LiveViews combine the concerns of controllers and views into a more unified model.

## Basic example

LiveView is included by default in new Phoenix applications. Let's see a simple example:

```elixir
defmodule MyAppWeb.ThermostatLive do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    Current temperature: {@temperature}°F
    <button phx-click="inc_temperature">+</button>
    """
  end

  def mount(_params, _session, socket) do
    temperature = 70 # Let's assume a fixed temperature for now
    {:ok, assign(socket, :temperature, temperature)}
  end

  def handle_event("inc_temperature", _params, socket) do
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end
end
```

This LiveView demonstrates the core lifecycle:

1. The `mount/3` callback initializes state when the LiveView starts
2. The `render/1` function defines what is displayed using [HEEx templates](components.md)
3. The `handle_event/3` callback responds to events from the client

To wire this up in your router:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  pipeline :browser do
    ...
  end

  scope "/", MyAppWeb do
    pipe_through :browser
    ...

    live "/thermostat", ThermostatLive
  end
end
```

Once the LiveView is rendered, a regular HTML response is sent. In your
app.js file, you should find the following:

```javascript
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
liveSocket.connect()
```

Now the JavaScript client will connect over WebSockets and `mount/3` will be invoked
inside a spawned LiveView process.

## Key concepts

### Socket and state

The LiveView socket is the fundamental data structure that holds all state in a LiveView. It's an immutable structure containing "assigns" - the data available to your templates. While controllers have `conn`, LiveViews have `socket`.

Changes to the socket (via `assign/3` or `update/3`) trigger re-renders. All state is maintained on the server, with only the diffs sent to the client, minimizing network traffic.

### LiveView lifecycle

LiveViews have several important lifecycle stages:

- [`mount`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:mount/3) - initializes the LiveView with parameters, session data, and socket
- [`handle_params`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:handle_params/3) - responds to URL changes and updates LiveView state accordingly
- [`handle_event`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:handle_event/3) - responds to user interactions coming from the client
- [`handle_info`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#c:handle_info/2) - responds to regular process messages

### DOM Bindings

LiveView provides DOM bindings for convenient client-server interaction:

```html
<button phx-click="inc_temperature">+</button>
<form phx-submit="save">...</form>
<input phx-blur="validate">
```

These bindings automatically send events to the server when the specified browser events occur, which are then handled in `handle_event/3`.

## Getting Started

Phoenix includes code generators for LiveView. Try:

```
$ mix phx.gen.live Blog Post posts title:string body:text
```

This generates a complete LiveView CRUD implementation, similar to `mix phx.gen.html`.

To learn more about LiveView, please refer to the [Phoenix LiveView documentation](https://hexdocs.pm/phoenix_live_view).
