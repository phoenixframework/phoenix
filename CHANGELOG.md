# Changelog for v1.8

This release requires Erlang/OTP 25+.

## `put_secure_browser_headers`

`put_secure_browser_headers` has been updated to the latest security practices. In particular, it sets the `content-security-policy` header to `"base-uri 'self'; frame-ancestors 'self';"` if none is set, restricting embedding of your application and the use of `<base>` element to same origin respectively. If you expect your application to be embedded by third-parties, you want to consult the documentation.

The headers `x-download-options` and `x-frame-options` are no longer set as they have been deprecated by standards.

## Deprecations

This release introduces deprecation warnings for several features that have been soft-deprecated in the past.

  * `use Phoenix.Controller` must now specify the `:formats` option, which may be set to an empty list if the formats are not known upfront
  * The `:namespace` and `:put_default_views` options on `use Phoenix.Controller` are deprecated and emit a warning on use
  * Specifying layouts without modules, such as `put_layout(conn, :print)` or `put_layout(conn, html: :print)` is deprecated
  * The `:trailing_slash` option in `Phoenix.Router` has been deprecated in favor of using `Phoenix.VerifiedRoutes`. The overall usage of helpers will be deprecated in the future

## v1.7

The CHANGELOG for v1.7 releases can be found in the [v1.7 branch](https://github.com/phoenixframework/phoenix/blob/v1.7/CHANGELOG.md).
