# Changelog for v1.9

## v1.9.0-dev

### Deprecation

  * [Phoenix.Router] Phoenix will now group your routes per verb during compilation when all `match :*` and `forward` routes are defined at the end of the router. This improves compilation times for large routers with no performance cost at runtime. If you have a route with an explicit verb after a `match :*` or `forward`, Phoenix will preserve the previous ordered matching semantics and emit a warning

## v1.8

The CHANGELOG for v1.8 releases can be found in the [v1.8 branch](https://github.com/phoenixframework/phoenix/blob/v1.8/CHANGELOG.md).
