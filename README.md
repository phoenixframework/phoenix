![phoenix logo](https://raw.githubusercontent.com/phoenixframework/phoenix/master/priv/static/phoenix.png)
> Elixir Web Framework targeting full-featured, fault tolerant applications with realtime functionality

[![Build Status](https://api.travis-ci.org/phoenixframework/phoenix.svg)](https://travis-ci.org/phoenixframework/phoenix)
[![Inline docs](http://inch-ci.org/github/phoenixframework/phoenix.svg)](http://inch-ci.org/github/phoenixframework/phoenix)

## Getting started

See the official site at http://www.phoenixframework.org/

## Documentation

API documentation is available at [http://hexdocs.pm/phoenix](http://hexdocs.pm/phoenix)

## Contributing

We appreciate any contribution to Phoenix, so check out our [CONTRIBUTING.md](CONTRIBUTING.md) guide for more information. We usually keep a list of features and bugs [in the issue tracker][1].

### Running a Phoenix master app

If you have previously installed Phoenix using mix archive.install [as described here](http://www.phoenixframework.org/v0.13.1/docs/up-and-running) then you will have to remove the archive.

```bash
mix archive.uninstall phoenix_new-x.x.x.ez # where x.x.x is your version
```

After that you can run the installer from the current Phoenix checkout.

```bash
$ cd installer
$ mix phoenix.new path/to/your/app --dev
```

The command above will create a new application, using your current Phoenix checkout thanks to the `--dev` flag.

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
