![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/master/priv/static/images/phoenix.png)
> Elixir Web Framework targeting full-featured, fault tolerant applications with realtime functionality

[![Build Status](https://api.travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)
[![Inline docs](http://inch-ci.org/github/phoenixframework/phoenix.svg)](http://inch-ci.org/github/phoenixframework/phoenix)

***

- [Documentation](#documentation)
- [Development](#development)
  - [Building phoenix.coffee](#building-phoenixcoffee)
- [Contributing](#contributing)
- [Important links](#important-links)
- [Feature Roadmap](#feature-roadmap)


## Getting started

- See the official site at http://www.phoenixframework.org/

## Documentation

API documentation is available at [http://hexdocs.pm/phoenix](http://hexdocs.pm/phoenix)


## Development

There are no guidelines yet. Do what feels natural. Submit a bug, join a discussion, open a pull request.

### Building phoenix.coffee

```bash
$ coffee -o priv/static/js -cw assets/cs
```

## Contributing

We appreciate any contribution to Phoenix, so check out our [CONTRIBUTING.md](CONTRIBUTING.md) guide for more information. We usually keep a list of features and bugs [in the issue tracker][1].

## Important links

* \#elixir-lang on freenode IRC
* [Issue tracker][1]
* [phoenix-talk Mailing list (questions)][2]
* [phoenix-core Mailing list (development)][3]

  [1]: https://github.com/phoenixframework/phoenix/issues
  [2]: http://groups.google.com/group/phoenix-talk
  [3]: http://groups.google.com/group/phoenix-core


## Feature Roadmap
- Robust Routing DSL
  - [x] GET/POST/PUT/PATCH/DELETE macros
  - [x] Named route helpers
  - [x] resource routing for RESTful endpoints
  - [x] Scoped definitions
  - [ ] Member/Collection resource  routes
- Configuration
  - [x] Environment based configuration with ExConf
  - [x] Integration with config.exs
- Middleware
  - [x] Plug Based Connection handling
  - [x] Code Reloading
  - [x] Environment Based logging with log levels with Elixir's Logger
  - [x] Static File serving
- Controllers
  - [x] html/json/text helpers
  - [x] redirects
  - [x] Plug layer for action hooks
  - [x] Error page handling
  - [x] Error page handling per env
- Views
  - [x] Precompiled View handling
  - [x] I18n
- Realtime
  - [x] Websocket multiplexing/channels
  - [x] Browser js client
  - [ ] iOS client (WIP)
  - [ ] Android client
