# Installation

In the [Overview Guide](overview.html) we got a look at the Phoenix ecosystem and how the pieces interrelate. Now it's time to install any software we might need before we jump into the [Up and Running Guide](up_and_running.html).

Please take a look at this list and make sure to install anything necessary for your system. Having dependencies installed in advance can prevent frustrating problems later on.

### Elixir 1.4 or later

Phoenix is written in Elixir, and our application code will also be written in Elixir. We won't get far in a Phoenix app without it! The Elixir site maintains a great [Installation Page](https://elixir-lang.org/install.html) to help.

If we have just installed Elixir for the first time, we will need to install the Hex package manager as well. Hex is necessary to get a Phoenix app running (by installing dependencies) and to install any extra dependencies we might need along the way.

Here's the command to install Hex (If you have Hex already installed, it will upgrade Hex to the latest version):

```console
$ mix local.hex
```

### Erlang 18 or later

Elixir code compiles to Erlang byte code to run on the Erlang virtual machine. Without Erlang, Elixir code has no virtual machine to run on, so we need to install Erlang as well.

When we install Elixir using instructions from the Elixir [Installation Page](https://elixir-lang.org/install.html),  we will usually get Erlang too. If Erlang was not installed along with Elixir, please see the [Erlang Instructions](https://elixir-lang.org/install.html#installing-erlang) section of the Elixir Installation Page for instructions.

People using Debian-based systems may need to explicitly install Erlang to get all the needed packages.

```console
$ wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && sudo dpkg -i erlang-solutions_1.0_all.deb
$ sudo apt-get update
$ sudo apt-get install esl-erlang
```

### Phoenix

To check that we are on Elixir 1.4 and Erlang 18 or later, run:
```console
elixir -v
Erlang/OTP 19 [erts-8.3] [source] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Elixir 1.4.2
```

Once we have Elixir and Erlang, we are ready to install the Phoenix Mix archive. A Mix archive is a Zip file which contains an application as well as its compiled BEAM files. It is tied to a specific version of the application. The archive is what we will use to generate a new, base Phoenix application which we can build from.

Here's the command to install the Phoenix archive:

```console
$ mix archive.install https://github.com/phoenixframework/archives/raw/master/phx_new.ez
```
> Note: if the Phoenix archive won't install properly with this command, we can download the package from the [Phoenix archives](https://github.com/phoenixframework/archives), save it to the filesystem, and then run: `mix archive.install /path/to/local/phx_new.ez`.

### Plug, Cowboy, and Ecto

These are either Elixir or Erlang projects which are part of Phoenix applications by default. We won't need to do anything special to install them. If we let Mix install our dependencies as we create our new application, these will be taken care of for us. If we don't, Phoenix will tell us how to do so after the app creation is done.

### node.js (>= 5.0.0)

Node is an optional dependency. Phoenix will use [brunch.io](http://brunch.io/) to compile static assets (JavaScript, CSS, etc), by default. Brunch.io uses the node package manager (npm) to install its dependencies, and npm requires node.js.

If we don't have any static assets, or we want to use another build tool, we can pass the `--no-brunch` flag when creating a new application and node won't be required at all.

We can get node.js from the [download page](https://nodejs.org/en/download/). When selecting a package to download, it's important to note that Phoenix requires version 5.0.0 or greater.

Mac OS X users can also install node.js via [homebrew](https://brew.sh/).

Note: io.js, which is an npm compatible platform originally based on Node.js, is not known to work with Phoenix.

Debian/Ubuntu users might see an error that looks like this:
```console
sh: 1: node: not found
npm WARN This failure might be due to the use of legacy binary "node"
```
This is due to Debian having conflicting binaries for node: [discussion on stackoverflow](http://stackoverflow.com/questions/21168141/can-not-install-packages-using-node-package-manager-in-ubuntu)

There are two options to fix this problem, either:
- install nodejs-legacy:
```console
$ apt-get install nodejs-legacy
```
or
- create a symlink
```console
$ ln -s /usr/bin/nodejs /usr/bin/node
```

### PostgreSQL

PostgreSQL is a relational database server. Phoenix configures applications to use it by default, but we can switch to MySQL by passing the `--database mysql` flag when creating a new application.

When we work with Ecto schemas in these guides, we will use PostgreSQL and the Postgrex adapter for it. In order to follow along with the examples, we should install PostgreSQL. The PostgreSQL wiki has [installation guides](https://wiki.postgresql.org/wiki/Detailed_installation_guides) for a number of different systems.

Postgrex is a direct Phoenix dependency, and it will be automatically installed along with the rest of our dependencies as we start our app.

### inotify-tools (for linux users)

This is a Linux-only filesystem watcher that Phoenix uses for live code reloading. (Mac OS X or Windows users can safely ignore it.)

Linux users need to install this dependency. Please consult the [inotify-tools wiki](https://github.com/rvoicilas/inotify-tools/wiki) for distribution-specific installation instructions.

### Skeleton Installation

Sometimes you want an installation without anything except the bare minimum phoenix setup. The following command will give you that.

`mix phx.new web --no-brunch --no-ecto`
