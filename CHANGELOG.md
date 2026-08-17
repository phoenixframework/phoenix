# Changelog for v1.9

## Enhancements

  * The longpoll session token is now sent in a `x-phoenix-longpoll-token`
    header instead of the query string. If you do rolling deploys where both
    old and new nodes are active at the same time, ensure that you deploy
    Phoenix v1.8.10 or a later v1.8 release first.

## Bug fixes

  * Longpoll session tokens are now bound to the socket handler that minted
    them, so a token from one `socket/3` mount can no longer be used to
    resume a session on another mount of the same endpoint. This changes the
    signing salt for longpoll tokens: tokens issued before upgrading will fail
    verification after upgrading and the client will transparently start a
    new session, the same as it does for any other expired/invalid token.

## v1.8

The CHANGELOG for v1.8 releases can be found in the [v1.8 branch](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
