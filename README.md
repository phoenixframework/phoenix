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

We appreciate any contribution to Phoenix, so check out our [CONTRIBUTING.md](CONTRIBUTING.md) guide for more information. We usually keep a list of features and bugs [in the issue tracker][1].

### Running a Phoenix master app

```bash
$ cd installer
$ mix phoenix.new path/to/your/app --dev
```

The command above will create a new application, using your current Phoenix checkout thanks to the `--dev` flag.

Note that `path/to/your/app` must be within the directory containing the Phoenix source code. This is so that a relative path can be used for the `:phoenix` dependency.

### Building phoenix.js

```bash
$ npm install
$ npm install -g brunch
$ brunch watch
```

## Important links

* \#elixir-lang on freenode IRC
* [Issue tracker][1]
* [phoenix-talk Mailing list (questions)][2]
* [phoenix-core Mailing list (development)][3]

  [1]: https://github.com/phoenixframework/phoenix/issues
  [2]: http://groups.google.com/group/phoenix-talk
  [3]: http://groups.google.com/group/phoenix-core
