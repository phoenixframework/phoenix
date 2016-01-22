![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/master/priv/static/phoenix.png)
> ### Productive. Reliable. Fast.
> A productive web framework that does not compromise speed and maintainability.

[![Build Status](https://api.travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)
[![Inline docs](http://inch-ci.org/github/phoenixframework/phoenix.svg)](http://inch-ci.org/github/phoenixframework/phoenix)

## Getting started

See the official site at http://www.phoenixframework.org/

## Documentation

API documentation is available at [http://hexdocs.pm/phoenix](http://hexdocs.pm/phoenix)

## Contributing

We appreciate any contribution to Phoenix. Check our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [CONTRIBUTING.md](CONTRIBUTING.md) guides for more information. We usually keep a list of features and bugs [in the issue tracker][4].

### Running a Phoenix master project

```bash
$ cd installer
$ mix phoenix.new path/to/your/project --dev
```

The command above will create a new project using your current Phoenix checkout, thanks to the `--dev` flag.

Note that `path/to/your/project` must be within the directory containing the Phoenix source code. This is so that a relative path can be used for the `:phoenix` dependency.

The command must be run from the `installer` directory. See the discussion in [PR 1224](https://github.com/phoenixframework/phoenix/pull/1224) for more information.

In order to test changes to the installer (the `phoenix.new` Mix task) itself, first remove any installed archive so that Mix will pick up the local source code.  This can be done with `mix archive.uninstall phoenix_new-#.#.#.ez` or by simply deleting the file, which is usually in `~/.mix/archives/`.

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
