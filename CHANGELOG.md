# Changelog for v1.9

## Enhancements

  * [Transports] Allow the longpoll session token to be sent in the
    `x-phoenix-longpoll-token` header instead of the query string, via
    `longpoll: [token_location: :header]`.
    Longpoll responses are now also sent with `cache-control: no-store`.

    Because the setting is negotiated per session and the server keeps
    accepting both, it can be flipped with a rolling deploy. Deploy a
    version that accepts both first, then switch to `:header` once no
    node predates it:

        socket "/socket", MyAppWeb.UserSocket,
          longpoll: [token_location: :header]

    Older clients that do not understand the negotiation keep using
    params and continue to work.

## v1.8

The CHANGELOG for v1.8 releases can be found in the [v1.8 branch](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
