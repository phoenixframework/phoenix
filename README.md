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

### Generating a Phoenix project from master

1. Remove any `phoenix_new` archives currently installed on your machine. There are two ways to do this:
  * Running `mix archive.uninstall <archive_name>`, usually `mix archive.uninstall phoenix_new.ez`
  * Deleting the archives directly, which can be found in `~/.mix/archives/`

2. Copy this directory via `git clone https://github.com/phoenixframework/phoenix` or by downloading it

3. Inside the `/installer` directory, the Mix command below will create a new project:
```bash
$ cd installer
$ mix phx.new dev_app --dev
```
The above command must be run from the `/installer` directory. For more, see the discussion in [PR 1224](https://github.com/phoenixframework/phoenix/pull/1224) 

### Installing Latest Archive
To create projects outside of the `/installer` directory, add the latest archive to your machine via: 
```bash
$ cd installer
$ mix archive.build && mix archive.install
```
You can then use `$ mix phx.new dev_app` in any directory you'd like.

### Phoenix Path
Depending on where it was created, your new project will have `:phoenix` configured as a relative path:
```
defp deps do
  [{:phoenix, path: "../..", override: true},
```
or as a Github URL:
```
defp deps do
  [{:phoenix, github: "phoenixframework/phoenix", override: true},
```

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
