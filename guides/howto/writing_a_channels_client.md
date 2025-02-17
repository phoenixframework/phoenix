# Writing a Channels Client

Client libraries for Phoenix Channels already exist in [several languages](https://hexdocs.pm/phoenix/channels.html#client-libraries), but if you want to write your own, this guide should get you started.
It may also be useful as a guide for manual testing with a WebSocket client.

## Overview

Because WebSockets are bidirectional, messages can flow in either direction at any time.
For this reason, clients typically use callbacks to handle incoming messages whenever they come.

A client must join at least one topic to begin sending and receiving messages, and may join any number of topics using the same connection.

## Connecting

To establish a WebSocket connection to Phoenix Channels, first make note of the `socket` declaration in the application's `Endpoint` module.
For example, if you see: `socket "/mobile", MyAppWeb.MobileSocket`, the path for the initial HTTP request is:

    [host]:[port]/mobile/websocket?vsn=2.0.0

Passing `&vsn=2.0.0` specifies `Phoenix.Socket.V2.JSONSerializer`, which is built into Phoenix, and which expects and returns messages in the form of lists.

You also need to include [the standard header fields for upgrading an HTTP request to a WebSocket connection](https://developer.mozilla.org/en-US/docs/Web/HTTP/Protocol_upgrade_mechanism) or use an HTTP library that handles this for you; in Elixir, [mint_web_socket](https://hex.pm/packages/mint_web_socket) is an example.

Other parameters or headers may be expected or required by the specific `connect/3` function in the application's socket module (in the example above, `MyAppWeb.MobileSocket.connect/3`).

## Message Format

The message format is determined by the serializer configured for the application.
For these examples, `Phoenix.Socket.V2.JSONSerializer` is assumed.

The general format for messages a client sends to a Phoenix Channel is as follows:

```
[join_reference, message_reference, topic_name, event_name, payload]
```

- The `join_reference` is also chosen by the client and should also be a unique value. It only needs to be sent for a `"phx_join"` event; for other messages it can be `null`. It is used as a message reference for `push` messages from the server, meaning those that are not replies to a specific client message. For example, imagine something like "a new user just joined the chat room".
- The `message_reference` is chosen by the client and should be a unique value. The server includes it in its reply so that the client knows which message the reply is for.
- The `topic_name` must be a known topic for the socket endpoint, and a client must join that topic before sending any messages on it.
- The `event_name` must match the first argument of a `handle_in` function on the server channel module.
- The `payload` should be a map and is passed as the second argument to that `handle_in` function.

There are three events that are understood by every Phoenix application.

First, `phx_join` is used join a channel. For example, to join the `miami:weather` channel:

```json
["0", "0", "miami:weather", "phx_join", {"some": "param"}]
```

Second, `phx_leave` is used to leave a channel. For example, to leave the `miami:weather` channel:

```json
[null, "1", "miami:weather", "phx_leave", {}]
```

Third, `heartbeat` is used to maintain the WebSocket connection. For example:


```json
[null, "2", "phoenix", "heartbeat", {}]
```

The `heartbeat` message is only needed when no other messages are being sent and prevents Phoenix from closing the connection; the exact `:timeout` is configured in the application's `Endpoint` module.

Other allowed messages depend on the Phoenix application.

For example, if the Channel serving the `miami:weather` can handle a `report_emergency` event:

```elixir
def handle_in("report_emergency", payload, socket) do
  MyApp.Emergencies.report(payload) # or whatever
  {:reply, :ok, socket}
end
```

...a client could send:

```json
[null, "3", "miami:weather", "report_emergency", {"category": "sharknado"}]
```
