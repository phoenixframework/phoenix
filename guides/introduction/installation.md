# Installation

In order to build a Phoenix application, we will need a few dependencies installed in our Operating System:

  * the Erlang VM and the Elixir programming language
  * a database - Phoenix recommends PostgreSQL but you can pick others or not use a database at all
  * Node.JS for assets - which can be opt-out, especially if you are building APIs
  * and other optional packages.

Please take a look at this list and make sure to install anything necessary for your system. Having dependencies installed in advance can prevent frustrating problems later on.

## Elixir 1.6 or later

Phoenix is written in Elixir, and our application code will also be written in Elixir. We won't get far in a Phoenix app without it! The Elixir site maintains a great [Installation Page](https://elixir-lang.org/install.html) to help.

If we have just installed Elixir for the first time, we will need to install the Hex package manager as well. Hex is necessary to get a Phoenix app running (by installing dependencies) and to install any extra dependencies we might need along the way.

Here's the command to install Hex (If you have Hex already installed, it will upgrade Hex to the latest version):

```console
$ mix local.hex
```

## Erlang 20 or later

Elixir code compiles to Erlang byte code to run on the Erlang virtual machine. Without Erlang, Elixir code has no virtual machine to run on, so we need to install Erlang as well.

When we install Elixir using instructions from the Elixir [Installation Page](https://elixir-lang.org/install.html),  we will usually get Erlang too. If Erlang was not installed along with Elixir, please see the [Erlang Instructions](https://elixir-lang.org/install.html#installing-erlang) section of the Elixir Installation Page for instructions.

> A note about Erlang and Phoenix: while Phoenix itself only requires Erlang 20 or later, one of Phoenix's dependencies, [cowboy](https://github.com/ninenines/cowboy), depends on Erlang 22 or later since cowboy 2.8.0. It is recommended to either install Erlang 22 or add `{:cowboy, "~> 2.7.0"}` to your mix.exs once your app has been created.

## Phoenix

To check that we are on Elixir 1.6 and Erlang 20 or later, run:

```console
elixir -v
Erlang/OTP 20 [erts-9.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Elixir 1.6.3
```

Once we have Elixir and Erlang, we are ready to install the Phoenix application generator:

```console
$ mix archive.install hex phx_new 1.5.0
```

The `phx.new` generator is now available to generate new applications in the next guide, called [Up and Running](up_and_running.html). The flags mentioned below are command line options to the generator; see all available options by calling `mix help phx.new`.

## node.js

Node is an optional dependency. Phoenix will use [webpack](https://webpack.js.org/) to compile static assets (JavaScript, CSS, etc), by default. Webpack uses the node package manager (npm) to install its dependencies, and npm requires node.js.

If we don't have any static assets, or we want to use another build tool, we can pass the `--no-webpack` flag when creating a new application and node won't be required at all.

We can get node.js from the [download page](https://nodejs.org/en/download/). When selecting a package to download, it's important to note that Phoenix requires version 5.0.0 or greater.

Mac OS X users can also install node.js via [homebrew](https://brew.sh/).

## PostgreSQL

PostgreSQL is a relational database server. Phoenix configures applications to use it by default, but we can switch to MySQL or MSSQL by passing the `--database` flag when creating a new application.

In order to talk to databases, Phoenix applications use another Elixir package, called [Ecto](https://github.com/elixir-ecto/ecto). If you don't plan to use databases in your application, you can pass the `--no-ecto` flag.

However, if you are just getting started with Phoenix, we recommend you to install PostgreSQL and make sure it is running. The PostgreSQL wiki has [installation guides](https://wiki.postgresql.org/wiki/Detailed_installation_guides) for a number of different systems.

## inotify-tools (for linux users)

Phoenix provides a very handy feature called Live Reloading. As you change your views or your assets, it automatically reloads the page in the browser. In order for this functionality to work, you need a filesystem watcher.

Mac OS X and Windows users already have a filesystem watcher but Linux users must install inotify-tools. Please consult the [inotify-tools wiki](https://github.com/rvoicilas/inotify-tools/wiki) for distribution-specific installation instructions.

## Summary

At the end of this section, you must have installed Elixir, Hex, Phoenix, PostgreSQL and node.js. Now that we have everything installed, let's create our first Phoenix application and get [up and running](up_and_running.html).
