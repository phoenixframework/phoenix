# Changelog for v1.9

This release requires Plug v1.21+.

## Enhancements

  * The longpoll session token is now sent in a `x-phoenix-longpoll-token`
    header instead of the query string. If you do rolling deploys where both
    old and new nodes are active at the same time, ensure that you deploy
    Phoenix v1.8.10 or a later v1.8 release first.

  * [Router] Add the `query` macro for routing HTTP QUERY (RFC 10008) requests ([#6737](https://github.com/phoenixframework/phoenix/pull/6737))

## v1.8

The CHANGELOG for v1.8 releases can be found in the [v1.8 branch](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
