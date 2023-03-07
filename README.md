![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/main/priv/static/phoenix.png)

> Peace of mind from prototype to production.

[![Build Status](https://github.com/phoenixframework/phoenix/workflows/CI/badge.svg)](https://github.com/phoenixframework/phoenix/actions/workflows/ci.yml) [![Hex.pm](https://img.shields.io/hexpm/v/phoenix.svg)](https://hex.pm/packages/phoenix) [![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/phoenix)

## Getting started

See the official site at <https://www.phoenixframework.org/>.

Install the latest version of Phoenix by following the instructions at <https://hexdocs.pm/phoenix/installation.html#phoenix>.

## Documentation

API documentation is available at <https://hexdocs.pm/phoenix>.

Phoenix.js documentation is available at <https://hexdocs.pm/phoenix/js>.

## Contributing

We appreciate any contribution to Phoenix. Check our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](CONTRIBUTING.md) guides for more information. We usually keep a list of features and bugs in the [issue tracker][4].

### Generating a Phoenix project from unreleased versions

You can create a new project using the latest Phoenix source installer (the `phx.new` Mix task) with the following steps:

1. Remove any previously installed `phx_new` archives so that Mix will pick up the local source code. This can be done with `mix archive.uninstall phx_new` or by simply deleting the file, which is usually in `~/.mix/archives/`.
2. Copy this repo via `git clone https://github.com/phoenixframework/phoenix` or by downloading it
3. Run the `phx.new` Mix task from within the `installer` directory, for example:

```bash
cd phoenix/installer
mix phx.new dev_app --dev
```

The `--dev` flag will configure your new project's `:phoenix` dep as a relative path dependency, pointing to your local Phoenix checkout:

```elixir
defp deps do
  [{:phoenix, path: "../..", override: true},
```

To create projects outside of the `installer/` directory, add the latest archive to your machine by following the instructions in [installer/README.md](https://github.com/phoenixframework/phoenix/blob/main/installer/README.md)

To build the documentation from source:

```bash
npm install --prefix assets
MIX_ENV=docs mix docs
```

To build Phoenix from source:

```bash
mix deps.get
mix compile
```

To build the Phoenix installer from source:

```bash
mix deps.get
mix compile
mix archive.build
```

### Building phoenix.js

```bash
cd assets
npm install
```

## Important links

* [#elixir][1] on [Libera][2] IRC
* [elixir-lang Slack channel][3]
* [Issue tracker][4]
* [Phoenix Forum (questions)][5]
* [phoenix-core Mailing list (development)][6]
* Visit Phoenix's sponsor, DockYard, for expert [phoenix consulting](https://dockyard.com/phoenix-consulting)
* Privately disclose security vulnerabilities to phoenix-security@googlegroups.com

  [1]: https://web.libera.chat/?channels=#elixir
  [2]: https://libera.chat/
  [3]: https://elixir-slackin.herokuapp.com/
  [4]: https://github.com/phoenixframework/phoenix/issues
  [5]: https://elixirforum.com/c/phoenix-forum
  [6]: https://groups.google.com/group/phoenix-core

## Copyright and License

Copyright (c) 2014, Chris McCord.

Phoenix source code is licensed under the [MIT License](LICENSE.md).
