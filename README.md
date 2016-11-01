![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/master/priv/static/phoenix.png)
> ### Productive. Reliable. Fast.
> A productive web framework that does not compromise speed and maintainability.

[![Build Status](https://api.travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)
[![Inline docs](http://inch-ci.org/github/phoenixframework/phoenix.svg)](http://inch-ci.org/github/phoenixframework/phoenix)

## Getting started

See the official site at http://www.phoenixframework.org/

## Documentation

API documentation is available at [https://hexdocs.pm/phoenix](https://hexdocs.pm/phoenix)

## Contributing

We appreciate any contribution to Phoenix. Check our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](CONTRIBUTING.md) guides for more information. We usually keep a list of features and bugs [in the issue tracker][4].

### Generating a Phoenix project from unreleased versions

In order to create a new project using the latest Phoenix source installer (the `phoenix.new` Mix task) you will need to ensure two things.

1. Remove any previously installed `phoenix_new` archives so that Mix will pick up the local source code. This can be done with `mix archive.uninstall phoenix_new.ez` or by simply deleting the file, which is usually in `~/.mix/archives/`.
2. Run the command from within the `installer` directory and provide a subdirectory within the installer to generate your dev project. The command below will create a new project using your current Phoenix checkout, thanks to the `--dev` flag.

```bash
$ cd installer
$ mix phoenix.new dev_app --dev
```

This will produce a new project that has `:phoenix` configured as a relative dependency:

```
defp deps do
  [{:phoenix, path: "../..", override: true},
```

The command must be run from the `installer` directory. See the discussion in [PR 1224](https://github.com/phoenixframework/phoenix/pull/1224) for more information.

### Building phoenix.js

```bash
$ npm install
$ npm install -g brunch
$ brunch watch
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
