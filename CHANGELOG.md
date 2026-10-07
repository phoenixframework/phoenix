# Changelog for v1.9

## Bug fixes

  * [Phoenix.ChannelTest] Fix test sockets violating the Phoenix.Socket.t
    typespec, which made Dialyzer treat every test join as never returning
    ([#5509](https://github.com/phoenixframework/phoenix/issues/5509))
  * [Phoenix.Socket] Type `topic` and `channel_pid` as possibly `nil` in
    `Phoenix.Socket.t`, as they are before a channel is joined

## Enhancements

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
