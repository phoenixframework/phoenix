# Changelog


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

