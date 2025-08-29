# Changelog for v1.8

This release requires Erlang/OTP 25+.

## Streamlined generators

  * Extend tailwindcss support in new apps with [daisyUI](https://daisyui.com/) for light/dark/system mode support for entire app, including core components
  * Simplify layout handling for new apps. Now there is only a single `root.html.heex` which wraps the render pipeline. Other dynamic layouts, like `app.html.heex` are called as needed within templates as regular function components
  * Simplify core components and live generators to more closely match basic `phx.gen.html` crud. This serves as a better base for seasoned devs to start with, and lessens the amount of code newcomers need to get up to speed with on the basics
  * Introduce magic links (passwordless auth) and "sudo mode" to `mix phx.gen.auth` while simplifying the generated structure
  * Introduce scopes to Phoenix generators, designed to make secure data access the *default*, not something you remember (or forget) to do later

## `put_secure_browser_headers`

`put_secure_browser_headers` has been updated to the latest security practices. In particular, it sets the `content-security-policy` header to `"base-uri 'self'; frame-ancestors 'self';"` if none is set, restricting embedding of your application and the use of `<base>` element to same origin respectively. If you expect your application to be embedded by third-parties, you want to consult the documentation.

The headers `x-download-options` and `x-frame-options` are no longer set as they have been deprecated by standards.

## Deprecations

This release introduces deprecation warnings for several features that have been soft-deprecated in the past.

  * `use Phoenix.Controller` must now specify the `:formats` option, which may be set to an empty list if the formats are not known upfront
  * The `:namespace` and `:put_default_views` options on `use Phoenix.Controller` are deprecated and emit a warning on use
  * Specifying layouts without modules, such as `put_layout(conn, :print)` or `put_layout(conn, html: :print)` is deprecated
  * The `:trailing_slash` option in `Phoenix.Router` has been deprecated in favor of using `Phoenix.VerifiedRoutes`. The overall usage of helpers will be deprecated in the future

## Potential breaking changes

  * The `config` variable is no longer available in `Phoenix.Endpoint`. In the past, it was possible to read your endpoint configuration at compile-time via an injected variable named `config`, which is no longer supported. Use `Application.compile_env/3` instead, which is tracked by the Elixir compiler and lead to a better developer experience. This may also lead to errors on application boot if you were previously incorrectly setting compile time config at runtime.

## 1.8.1 (2025-08-28)

### Bug fixes
  - [phx.new] Fix AGENTS.md failing to include CSS and JavaScript sections

## 1.8.0 (2025-08-05)

### Bug fixes
  - [phx.new] Don't include node_modules override in generated `tsconfig.json`

### Enhancements
  - [phx.gen.live|html|json] - Make context argument optional. Defaults to the plural name.
  - [phx.new] Add `mix precommit` alias
  - [phx.new] Add `AGENTS.md` generation compatible with [`usage_rules`](https://hexdocs.pm/usage_rules/)
  - [phx.new] Add `usage_rules` folder to installer, allowing to sync generic Phoenix rules into new projects
  - [phx.new] Use LiveView 1.1 release in generated code
  - [phx.new] Ensure theme selector and flash closing works without LiveView

## 1.8.0-rc.4 (2025-07-14)

### Bug Fixes
  - Fix phx.gen.presence PubSub server name for umbrella apps
  - Fix `phx.gen.live` subscribing to pubsub in disconnected mounts

### Enhancements
  - [phx.new] Initialize initial git repo when git is installed
  - [phx.new] Opt-in to HEEx `:debug_tags_location` in development
  - [phx.gen.live|html|json|context] Make context name optional and inflect based on schema when missing
  - [phx.gen.*] Use new Ecto 3.13 `Repo.transact/2` in generators
  - [phx.gen.auth] Warn when using `phx.gen.auth` without esbuild as features assume `phoenix_html.js` in bundle
  - Add `security.md` guide for security best practices
  - [phoenix.js] - Add fetch() support to LongPoll when XMLHTTPRequest is not available
  - Optimize parameter scrubbing by precompiling patterns

## 1.8.0-rc.3 (2025-05-07)

### Enhancements
  - [phx.gen.auth] Allow configuring the scope's assign key in phx.gen.auth
  - [phx.new] Do not override theme in root layout if explicitly set

## 1.8.0-rc.2 (2025-04-29)

### Bug Fixes
  - [phx.gen.live] Only subscribe to pubsub if connected
  - [phx.gen.auth] Remove unused current_password field
  - [phx.gen.auth] Use context_app for scopes to fix generated scopes in umbrella apps

## 1.8.0-rc.1 (2025-04-16)

### Enhancements
  - [phx.new] Support PORT in dev
  - [phx.gen.auth] Replace `utc_now/0 + truncate/1` with `utc_now/1`
  - [phx.gen.auth] Make dev mailbox link more obvious

### Bug Fixes
  - [phx.new] Fix Tailwind custom variants for loading classes (#6194)
  - [phx.new] Fix heroicons path for umbrella apps
  - [phx.gen.auth] Fix missing index for scoped resources (#6186)
  - [phx.gen.live] Fix crash when an open :show page gets a PubSub broadcast for items (#6197)

## 1.8.0-rc.0 (2025-04-01) 🚀

- First release candidate!

## v1.7

The CHANGELOG for v1.7 releases can be found in the [v1.7 branch](https://github.com/phoenixframework/phoenix/blob/v1.7/CHANGELOG.md).
