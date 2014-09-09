# Changelog

## v0.4.1 (2014-09-08)

* Bug fixes
  * [Project Generation] Fix project template dependencies pointing to incorrect phoenix and elixir versions


## v0.4.0 (2014-08-30)

* Enhancements
  * [Controller] Controllers are now Plugs and can be plugged as a "second layer" plug stack from the Router plug stack
  * [Controller] Elixir Logger Integration - Improved request logger, durations, params, etc
  * [Controller] Custom 404/500 page handling, [details](https://github.com/phoenixframework/phoenix/blob/0b6bdffab45fc46bc1455860f2d3971d0224eeb5/README.md#custom-not-found-and-error-pages)
  * [Controller] Ability to halt Plug stacks with Plug 0.7.0 `halt/1`
  * [Controller] Add `assign_layout/2` and `assign_status/2`
  * [Controller] Flash messages for one-time message support across redirects
  * [View] Internationalization support
  * [View] New `Template.Engine` behaviour for third-party template engines. See [PhoenixHaml](https://github.com/chrismccord/phoenix_haml) for haml support via Calliope.
  * `render/2` can be explicitly plugged for automatic rendering of actions based on action name
  * [Channel] Assign API for Sockets allows ephemeral state to be stored on the multiplexed socket, similar to conn assigns
  * [Config] Add `proxy_port` Router config option for deployments where public facing port differs from local port
  * [Router] Add nested generated `Helpers` module to Routers for easy imports of named route helpers, ie `import MyApp.Router.Helpers`


* Bug fixes
  * Various bug fixes and improvements

* Backwards incompatible changes
  * [Config] ExConf Configuration has been replaced by Mix Config
  * Directory and naming conventions have changed. A `web/` directory now lives at root of the project and holds routers, controllers, channels, views & templates, where all `web/` files are recompiled by the code reloader during development. Modules that cannot be simply recompiled in process are placed in lib as normal and require a server restart to take effect. Follow [this guide](https://gist.github.com/dgoldie/2fdc90fe09ecdddb78f4) for upgrade steps from 0.3.x.
  * Naming conventions now use singular form for module names, directory names, and named route helpers
  * [Router] Named route helpers have been reworked to use single function name with pattern matched arguments. See the [readme  examples](https://github.com/phoenixframework/phoenix/blob/0b6bdffab45fc46bc1455860f2d3971d0224eeb5/README.md#resources)
  * [Controller] `layout: nil` render option has been replaced by `assign_layout(conn, :none)`
  * [Plugs] `Plugs.JSON` now adds parsed params under "_json" key when the JSON object is an array


## v0.3.1 (2014-07-04)
* Enhancements
  * Various performance improvements

## v0.3.0 (2014-06-30)

* Enhancements
  * Add Precompiled EEx Templating Engine and View layer
  * Add JSON Plug parser
  * Update Plug to 0.5.2 with Cookie Session support
  * URL helpers ie, `Router.page_path`, now properly encode nested query string params

* Bug fixes
  * Auto template compilation has been fixed for Elixir 0.14.2 `@external_resource` changes

* Backwards incompatible changes
  * Controller action arity has changed. All actions now receive the Plug conn and params as arguments, ie `def show(conn, %{"id" => id})`
  * Channel and Topic `reply` and `broadcast` functions now require a map instead of an arbitrary dict

