# Installation

In order to build a Phoenix application, we will need a few dependencies installed in our Operating System:

  * the Erlang VM and the Elixir programming language
  * a database - Phoenix recommends PostgreSQL, but you can pick others or not use a database at all
  * and other optional packages.

Please take a look at this list and make sure to install anything necessary for your system. Having dependencies installed in advance can prevent frustrating problems later on.

If you just want to get started quickly, the [Up and Running](up_and_running.md) page includes a link to Phoenix Express, which will get Erlang, Elixir and Phoenix installed and running in seconds.

## Elixir 1.15 or later

Phoenix is written in Elixir, and our application code will also be written in Elixir. We won't get far in a Phoenix app without it! The Elixir site maintains a great [Installation Page](https://elixir-lang.org/install.html) to help.

## Erlang 24 or later

Elixir code compiles to Erlang byte code to run on the Erlang virtual machine. Without Erlang, Elixir code has no virtual machine to run on, so we need to install Erlang as well.

When we install Elixir using instructions from the Elixir [Installation Page](https://elixir-lang.org/install.html),  we will usually get Erlang too. If Erlang was not installed along with Elixir, please see the [Erlang Instructions](https://elixir-lang.org/install.html#installing-erlang) section of the Elixir Installation Page for instructions.

## Phoenix

To check that we are on Elixir 1.15 and Erlang 24 or later, run:

```console
elixir -v
Erlang/OTP 24 [erts-12.0] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Elixir 1.15.0
```

Once we have Elixir and Erlang, we are ready to install the Phoenix application generator:

```console
$ mix archive.install hex phx_new
```

The `phx.new` generator is now available to generate new applications in the next guide, called [Up and Running](up_and_running.html). The flags mentioned below are command line options to the generator; see all available options by calling `mix help phx.new`.

## PostgreSQL

PostgreSQL is a relational database server. Phoenix configures applications to use it by default, but we can switch to MySQL, MSSQL, or SQLite3 by passing the `--database` flag when creating a new application.

In order to talk to databases, Phoenix applications use another Elixir package, called [Ecto](https://github.com/elixir-ecto/ecto). If you don't plan to use databases in your application, you can pass the `--no-ecto` flag.

However, if you are just getting started with Phoenix, we recommend you to install PostgreSQL and make sure it is running. The PostgreSQL wiki has [installation guides](https://wiki.postgresql.org/wiki/Detailed_installation_guides) for a number of different systems.

## inotify-tools (for Linux users)

Phoenix provides a very handy feature called Live Reloading. As you change your views or your assets, it automatically reloads the page in the browser. In order for this functionality to work, you need a filesystem watcher.

macOS and Windows users already have a filesystem watcher, but Linux users must install inotify-tools. Please consult the [inotify-tools wiki](https://github.com/rvoicilas/inotify-tools/wiki) for distribution-specific installation instructions.

## Summary

At the end of this section, you must have installed Elixir, Hex, Phoenix, and PostgreSQL. Now that we have everything installed, let's create our first Phoenix application and get [up and running](up_and_running.html).
