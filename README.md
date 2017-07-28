![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/master/priv/static/phoenix.png)
> ### Productive. Reliable. Fast.
> A productive web framework that does not compromise speed and maintainability.

[![Build Status](https://api.travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)
[![Inline docs](http://inch-ci.org/github/phoenixframework/phoenix.svg)](http://inch-ci.org/github/phoenixframework/phoenix)

## Getting started

See the official site at http://www.phoenixframework.org/

## Documentation

API documentation is available at [https://hexdocs.pm/phoenix](https://hexdocs.pm/phoenix)

Phoenix.js documentation is available at [https://hexdocs.pm/phoenix/js](https://hexdocs.pm/phoenix/js)

## Contributing

We appreciate any contribution to Phoenix. Check our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](CONTRIBUTING.md) guides for more information. We usually keep a list of features and bugs [in the issue tracker][4].

### Generating a Phoenix project from unreleased versions

You can create a new project using the latest Phoenix source installer (the `phx.new` Mix task) with the following steps:

1. Remove any previously installed `phx_new` archives so that Mix will pick up the local source code. This can be done with `mix archive.uninstall phx_new` or by simply deleting the file, which is usually in `~/.mix/archives/`.
2. Copy this repo via `git clone https://github.com/phoenixframework/phoenix` or by downloading it
3. Run the `phx.new` mix task from within the `installer` directory, for example:

```bash
$ cd installer
$ mix phx.new dev_app --dev
```

The `--dev` flag will configure your new project's `:phoenix` dep as a relative path dependency, pointing to your local Phoenix checkout:

```elixir
defp deps do
  [{:phoenix, path: "../..", override: true},
```

To create projects outside of the `installer/` directory, add the latest archive to your machine by following the instructions in [installer/README.md](https://github.com/phoenixframework/phoenix/blob/master/installer/README.md)

### Building phoenix.js

```bash
$ npm install
$ npm run watch
```

### Building docs from source

```bash
$ MIX_ENV=docs mix docs
```

## Important links

* [#elixir-lang][1] on [Freenode][2] IRC
* [elixir-lang slack channel][3]
* [Issue tracker][4]
* [phoenix-talk Mailing list (questions)][5]
* [phoenix-core Mailing list (development)][6]
* Visit Phoenix's sponsor, DockYard, for expert [phoenix consulting](https://dockyard.com/phoenix-consulting)
* Privately disclose security vulnerabilities to phoenix-security@googlegroups.com

  [1]: https://webchat.freenode.net/?channels=#elixir-lang
  [2]: http://www.freenode.net/
  [3]: https://elixir-slackin.herokuapp.com/
  [4]: https://github.com/phoenixframework/phoenix/issues
  [5]: http://groups.google.com/group/phoenix-talk
  [6]: http://groups.google.com/group/phoenix-core

## Copyright and License

Copyright (c) 2014, Chris McCord.

Phoenix source code is licensed under the [MIT License](LICENSE.md).
