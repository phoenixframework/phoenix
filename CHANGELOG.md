# Changelog for v1.9

## Bug fixes

  * [phoenix.js] Send the fallback health check before the buffered join, so
    that a working WebSocket no longer falls back to LongPoll when the join
    takes longer than `longPollFallbackMs`
    ([#6770](https://github.com/phoenixframework/phoenix/issues/6770))
  * [Phoenix.ChannelTest] Fix test sockets violating the Phoenix.Socket.t
    typespec, which made Dialyzer treat every test join as never returning
    ([#5509](https://github.com/phoenixframework/phoenix/issues/5509))
  * [Phoenix.Socket] Type `topic` and `channel_pid` as possibly `nil` in
    `Phoenix.Socket.t`, as they are before a channel is joined

## Enhancements

  * [phoenix.js] Long polling retries interrupted requests without rejoining
    channels while its server session remains alive. Both sides number their
    messages: the server keeps its messages until the client acknowledges them,
    and drops the messages the client sends again. New `socket.onSuspend` and
    `socket.onResume` callbacks report interruptions and recovery without a
    channel error, and the new `resumeAfterMs` socket option sets the delay
    between retries. Long polling requires clients and nodes of Phoenix v1.8.18
    or later, which number their messages. If you do rolling deploys where both
    old and new nodes are active at the same time, ensure that you deploy
    Phoenix v1.8.18 or a later v1.8 release first. Browsers that still run
    phoenix.js of an older release cannot long poll until they reload the page.
  * [phoenix.js] Resume WebSockets over a new connection without rejoining
    channels. Clients opt in with the new `resumable: true` socket option, which
    requires the new `:resumable` WebSocket option of `Phoenix.Endpoint.socket/3`.
    When the WebSocket fails or the heartbeat times out, the socket resumes its
    session over a new WebSocket, and both sides send the messages the other side
    missed. `:resumable` can also be a function that decides for each connection
  * [Phoenix.Socket] Add the optional `c:Phoenix.Socket.resume/3` callback to check
    a client that resumes its socket over a new WebSocket or with the poll after a
    failed long-poll request, for example to verify that the user is still logged
    in. Returning `:error` stops the socket, so the client connects again. Custom
    transports can implement the new optional
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
