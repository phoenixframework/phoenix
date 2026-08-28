# Changelog for v1.9

## Enhancements

  * The longpoll session token is now sent in a `x-phoenix-longpoll-token`
    header instead of the query string. If you do rolling deploys where both
    old and new nodes are active at the same time, ensure that you deploy
    Phoenix v1.8.10 or a later v1.8 release first.

## v1.8

The CHANGELOG for v1.8 releases can be found in the [v1.8 branch](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
