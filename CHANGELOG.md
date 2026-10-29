# Changelog for v1.9

## Bug fixes

  * [Phoenix.ChannelTest] Fix test sockets violating the Phoenix.Socket.t
    typespec, which made Dialyzer treat every test join as never returning
    ([#5509](https://github.com/phoenixframework/phoenix/issues/5509))
  * [Phoenix.Socket] Type `topic` and `channel_pid` as possibly `nil` in
    `Phoenix.Socket.t`, as they are before a channel is joined

## Enhancements

  * [phoenix.js] Long polling retries interrupted requests without rejoining
    channels while its server session remains alive. Messages are retained until
    acknowledged and retried pushes are deduplicated. New `socket.onSuspend` and
    `socket.onResume` callbacks report interruptions and recovery without a
    channel error. Older servers retain the existing reconnect behavior. During
    a rolling deploy, a session that reaches a node with an older server falls
    back to that behavior for the rest of the session.
  * [Phoenix.Endpoint] Add the `:resumable` WebSocket option. Clients that use the
    `resumable: true` option of the `phoenix.js` Socket resume the socket over a new
    WebSocket after the connection failed or the heartbeat timed out, without
    rejoining channels. Both sides send the messages the other side missed. Clients
    connecting to servers without the option behave like before
  * [Phoenix.Socket] Add the optional `c:Phoenix.Socket.resume/3` callback to check
    a client that resumes its session after a failed request or WebSocket, for example
    to verify that the user is still logged in. Returning `:error` stops the socket,
    so the client connects again. Custom transports can implement the new optional
    `c:Phoenix.Socket.Transport.handle_resume/2` callback
  * The longpoll session token is now sent in a `x-phoenix-longpoll-token`
    header instead of the query string. If you do rolling deploys where both
    old and new nodes are active at the same time, ensure that you deploy
    Phoenix v1.8.10 or a later v1.8 release first.
  * Channels now use the `Phoenix.PubSub.Sender` behaviour for fastlaning,
    which requires `phoenix_pubsub` v2.4. If you do rolling deploys where both
    old and new nodes are active at the same time, ensure that you deploy
    Phoenix v1.8.16 or a later v1.8 release first.

## v1.8

The CHANGELOG for v1.8 releases can be found in the [v1.8 branch](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
