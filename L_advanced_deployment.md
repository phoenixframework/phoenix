### What We'll Need

There are just a few things we'll need before we continue.

- a working application
- a build environment - this can be our dev environment
- a hosting environment - this can be our build environment for testing/experimentation

We need to be sure that the architectures for both our build and hosting environments are the same, e.g. 64-bit Linux -> 64-bit Linux. If the architectures don't match, our application might not run when deployed. Using a virtual machine that mirrors our hosting environment as our build environment is an easy way to avoid that problem.

### Goals

Our main goal for this guide is to generate a release, using the [Elixir Release Manager](https://github.com/bitwalker/exrm) (exrm), and deploy it to our hosting environment. Once we have our application running, we will discuss steps needed to make it publicly visible.

## Tasks

Let's separate our release process into a few tasks so we can keep track of where we are.

- Add exrm as a dependency
- Generate a release
- Test it
- Deploy it
- Make it public

## Add exrm as a Dependency

To get started, we'll need to add `{:exrm, "~> 0.14.16"}` into the list of dependencies in our `mix.exs` file.

```elixir
  defp deps do
    [{:phoenix, "~> 0.13"},
     {:phoenix_ecto, "~> 0.4"},
     {:postgrex, ">= 0.0.0"},
     {:phoenix_html, "~> 1.0"},
     {:phoenix_live_reload, "~> 0.4", only: :dev},
     {:cowboy, "~> 1.0"},
     {:exrm, "~> 0.14.16"}]
  end
```
With that taken care of, a simple `mix do deps.get, compile` will pull down exrm and its dependencies, along with the rest of our application's dependencies. It also ensures that everything compiles properly. If all goes well, exrm's mix tasks will be available.

```console
$ mix help
. . .
mix release           # Build a release for the current mix application.
mix release.clean     # Clean up any release-related files.
mix release.plugins   # View information about active release plugins
. . .
```

### Configure Our Applications

Now we need to update our `mix.exs` file to have all production dependencies listed in the `applications` list in the `application/0` function.

```elixir
  def application do
    [mod: {HelloPhoenix, []},
      applications: [:phoenix, :cowboy, :logger, :postgrex, :phoenix_ecto, :phoenix_html]]
  end
```
Doing this helps us overcome one of [exrm's common issues](https://github.com/bitwalker/exrm#common-issues) by helping exrm know about all our dependencies so that it can properly bundle them into our release. Without this, our application will probably alert us about missing modules or a failure to start a child application when we go to run our release.

Even if we list all of our dependencies, our application may still fail. Typically, this happens because one of our dependencies does not properly list its own dependencies. A quick fix for this is to include the missing dependency or dependencies in our list of applications. If this happens to you, and you feel like helping the community, you can create an issue or a pull request to that project's repo.

In versions of Phoenix previous to 0.8.0, we needed to take an extra step of starting our Endpoint (or router for older versions) inside our application's `start/2` function. This is no longer necessary as our Endpoint is registered as a worker which will be started by the Supervisor. We can see this in our `lib/hello_phoenix.ex` file.

```elixir
defmodule HelloPhoenix do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the endpoint when the application starts
      worker(HelloPhoenix.Endpoint, []),

      # Here you could define other workers and supervisors as children
      # worker(HelloPhoenix.Worker, [arg1, arg2, arg3]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HelloPhoenix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    HelloPhoenix.Endpoint.config_change(changed, removed)
    :ok
  end
end
```
Note: Just to be extra clear, this file is named after our application. If we had called it `MyApp`, this file would be `lib/my_app.ex`.

There's one last thing we need to do before we create our release. We need to configure our Endpoint to act as a server in `config.exs`.

```elixir
# Configures the endpoint
config :hello_phoenix, HelloPhoenix.Endpoint,
url: [host: "localhost"],
secret_key_base: "OOmSQ22Liduec/twplfKrEseNL2m7ivMK32ywKECyhckgQVLtBCxS3cMusKD2v8f",
debug_errors: false,
server: true
```
When we run `$ mix phoenix.server` to start our application, that mix task automatically sets the server parameter to true. When we're creating a release, however, we need to make sure that we have this manually configured. If you get through this release guide, and you aren't seeing any pages coming from your server, this is a likely culprit.

### Generating the Release

Now that we've configured our application, let's build our release by running `mix release` at the root of our application.

```console
$ mix release
==> Building release with MIX_ENV=dev.
==> Generating relx configuration...
==> Generating sys.config...
==> Generating boot script...
==> Performing protocol consolidation...
==> Conform: Loading schema...
==> Conform: No schema found, conform will not be packaged in this release!
==> Generating release...
==> Generating nodetool...
==> Packaging release...
==> The release for hello_phoenix-0.0.1 is ready!
```
There are a couple of interesting things to note here.
- Since we didn't specify a `MIX_ENV` value, we got `dev` by default. Right now, we're experimenting. If we were doing a real release, we would want to specify `MIX_ENV=prod` when we run `mix release`.

- We see our application's version number - `0.0.1`. This value comes from the application's `mix.exs` file. It is mapped to the `:version` key inside the `project/0` function.

- Exrm has created a `rel` directory at the root of our application where it has written everything related to this release.

Exrm uses a set of default configuration options when building our release that will work for most applications. If we need more advanced configuration options, we can checkout [exrm's configuration section](https://github.com/bitwalker/exrm#configuration) for more detailed information.

If we make a mistake, or if something doesn't go quite right, we can run `mix release.clean`, which will delete the release for the current application version number. If we add the `--implode` flag, expm will remove _all_ releases for all versions of our application. These will be permanently removed unless they are under version control. Obviously, this is a destructive operation, and expm will prompt us to make sure we want to continue.

#### Contents of a Release

Exrm has created our release, and put it somewhere in the `rel` directory, but where exactly did all the pieces end up?

Everything related to our releases is in the `rel/hello_phoenix` directory. Let's see what's in it.

```console
$ ls -la rel/hello_phoenix/
total 21064
drwxr-xr-x   7 lance  staff       238 Jan  4 14:16 .
drwxr-xr-x   3 lance  staff       102 Jan  4 14:16 ..
drwxr-xr-x   6 lance  staff       204 Jan  4 14:16 bin
drwxr-xr-x   6 lance  staff       204 Jan  4 14:16 erts-6.3
-rw-r--r--   1 lance  staff  10784459 Jan  4 14:16 hello_phoenix-0.0.1.tar.gz
drwxr-xr-x  19 lance  staff       646 Jan  4 14:16 lib
drwxr-xr-x   5 lance  staff       170 Jan  4 14:16 releases
```

The `bin` directory contains the generated executables for running our application. The `bin/hello_phoenix` executable is what we will use to issue commands to our application.

```console
$ ls -la rel/hello_phoenix/bin
total 80
drwxr-xr-x  6 lance  staff    204 Jan  4 14:16 .
drwxr-xr-x  7 lance  staff    238 Jan  4 14:16 ..
-rwxr-xr-x  1 lance  staff  13499 Jan  4 14:16 hello_phoenix
-rw-r--r--  1 lance  staff   4400 Jan  4 14:16 install_upgrade.escript
-rwxr-xr-x  1 lance  staff   5373 Jan  4 14:16 nodetool
-r--r--r--  1 lance  admin   5283 Dec 12 07:45 start_clean.boot
```

The `erts-6.3` directory contains all necessary files for the Erlang run-time system, pulled from our build environment.

```console
$ ls -la rel/hello_phoenix/erts-6.3/
total 0
drwxr-xr-x   6 lance  staff  204 Jan  4 14:16 .
drwxr-xr-x   7 lance  staff  238 Jan  4 14:16 ..
drwxr-xr-x  24 lance  staff  816 Jan  4 14:16 bin
drwxr-xr-x  12 lance  staff  408 Jan  4 14:16 include
drwxr-xr-x   5 lance  staff  170 Jan  4 14:16 lib
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 src
```

The `lib` directory contains the compiled BEAM files for our application and all of our dependencies. This is where all of our work goes.

```console
$ ls -la rel/hello_phoenix/lib/
total 0
drwxr-xr-x  19 lance  staff  646 Jan 16 16:03 .
drwxr-xr-x   7 lance  staff  238 Jan 16 16:04 ..
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 compiler-5.0
drwxr-xr-x  13 lance  staff  442 Jan 16 16:03 consolidated
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 cowboy-1.0.0
drwxr-xr-x   4 lance  staff  136 Jan 16 16:03 cowlib-1.0.1
drwxr-xr-x   4 lance  staff  136 Jan 16 16:03 crypto-3.3
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 elixir-1.0.2
drwxr-xr-x   4 lance  staff  136 Jan 16 16:03 hello_phoenix-0.0.1
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 iex-1.0.2
drwxr-xr-x   4 lance  staff  136 Jan 16 16:03 kernel-3.0
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 logger-1.0.2
drwxr-xr-x   4 lance  staff  136 Jan 16 16:03 phoenix-0.10.0
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 plug-0.11.1
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 poison-1.3.0
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 ranch-1.0.0
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 sasl-2.4
drwxr-xr-x   4 lance  staff  136 Jan 16 16:03 stdlib-2.0
drwxr-xr-x   3 lance  staff  102 Jan 16 16:03 syntax_tools-1.6.14
```

The `releases` directory is the home for our releases - any release-dependent configurations and scripts that exrm finds necessary for running our application. If we have multiple versions of our application, and if we have created releases for them, we will have multiple releases in the `releases` directory.

```console
$ ls -la rel/hello_phoenix/releases/
total 16
drwxr-xr-x  5 lance  staff  170 Jan  4 14:16 .
drwxr-xr-x  7 lance  staff  238 Jan  4 14:16 ..
drwxr-xr-x  8 lance  staff  272 Jan  4 14:16 0.0.1
-rw-r--r--  1 lance  staff  875 Jan  4 14:16 RELEASES
-rw-r--r--  1 lance  staff    9 Jan  4 14:16 start_erl.data
```

The `hello_phoenix-0.0.1.tar.gz` tarball is our release in archive form, ready to be shipped off to our hosting environment.

### Testing Our Release

Before deploying our release, we should make sure that it runs in our build environment. To do that, we will issue the `console` command to our executable, essentially running our application via `iex`.

```console
$ rel/hello_phoenix/bin/hello_phoenix console
Exec: /Users/lance/work/hello_phoenix/rel/hello_phoenix/erts-6.0/bin/erlexec -boot /Users/lance/work/hello_phoenix/rel/hello_phoenix/releases/0.0.1/hello_phoenix -boot_var ERTS_LIB_DIR /Users/lance/work/hello_phoenix/rel/hello_phoenix/erts-6.0/../lib -env ERL_LIBS /Users/lance/work/hello_phoenix/rel/hello_phoenix/lib -config /Users/lance/work/hello_phoenix/rel/hello_phoenix/releases/0.0.1/sys.config -pa /Users/lance/work/hello_phoenix/rel/hello_phoenix/lib/consolidated -args_file /Users/lance/work/hello_phoenix/rel/hello_phoenix/releases/0.0.1/vm.args -user Elixir.IEx.CLI -extra --no-halt +iex -- console
Root: /Users/lance/work/hello_phoenix/rel/hello_phoenix
/Users/lance/work/hello_phoenix/rel/hello_phoenix
Erlang/OTP 17 [erts-6.0] [source-07b8f44] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

[debug] Running HelloPhoenix.Endpoint with Cowboy on port 4000 (http)
Interactive Elixir (1.0.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(hello_phoenix@127.0.0.1)1>

```
This is the point where our application will crash if it fails to start a child application. If all goes well, however, we should end up at an `iex` prompt. We should also see our app running at [http://localhost:4000/](http://localhost:4000/).

Let's hit `ctrl-c` twice to get out of iex so that we can explore a couple of different ways to interact with our release.

One thing we can do is start the release without a console session. Let's try running the `start` command.

```console
$ rel/hello_phoenix/bin/hello_phoenix start
```
And we see . . . nothing except that our prompt comes right back. This is ok!

We can check to make sure that it is really ok by pinging the release.

```console
$ rel/hello_phoenix/bin/hello_phoenix ping
pong
```
Great, it's responding.

Now let's try connecting a console to the running release with the `remote_console` command.

```console
$ rel/hello_phoenix/bin/hello_phoenix remote_console
Erlang/OTP 17 [erts-6.0] [source-07b8f44] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.0.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(hello_phoenix@127.0.0.1)1>
```
That worked. At this point, we can run any commands we might normally run in a console session.

Ok, let's get out of this session by hitting `ctrl-c` twice again. What happens if we ping the release again?

```console
$ rel/hello_phoenix/bin/hello_phoenix ping
pong
```
It's still alive and responding. This is a feature! If the server were to go down every time we stopped a remote console, that would be a problem. Note that this situation is different from when we ran the `console` command above. The `remote_console` command is not intended to start a release locally, but rather to connect to one which has already started.

So how _do_ we stop the server, then? There are two ways.

One way is to simply issue the `stop` command.

```console
$ rel/hello_phoenix/bin/hello_phoenix stop
ok
```
That looks promising. What happens if we ping the server again?

```console
$ rel/hello_phoenix/bin/hello_phoenix ping
Node 'hello_phoenix@127.0.0.1' not responding to pings.
```
Success.

Ok, let's re-start our release and establish a remote console to try the other way of stopping it.

```console
$ rel/hello_phoenix/bin/hello_phoenix start
$ rel/hello_phoenix/bin/hello_phoenix remote_console
Erlang/OTP 17 [erts-6.0] [source-07b8f44] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.0.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(hello_phoenix@127.0.0.1)1>
```
Great. Now at the prompt, let's issue this command `:init.stop`.

```console
iex(hello_phoenix@127.0.0.1)1> :init.stop
:ok
```
Then let's hit `ctrl-c` twice again to exit our iex session and ping the server to see if it responds.

```console
$ rel/hello_phoenix/bin/hello_phoenix ping
Node 'hello_phoenix@127.0.0.1' not responding to pings.
```
As we expected, the server is now down.

Congratulations! Now that we've interacted a bit with our release locally, we're ready to deploy our application!

## Deploying Our Release

There are many ways for us to get our tarballed release to our hosting environment. In our example, we'll use SCP to upload to a remote server.

```console
$ scp -i ~/.ssh/id_rsa.pub rel/hello_phoenix-0.0.1.tar.gz ubuntu@hostname.com:/home/ubuntu
hello_phoenix-0.0.1.tar.gz                100%   18MB  80.0KB/s   03:48
```
Let's SSH into that environment to set our application up.

```console
$ ssh -i ~/.ssh/id_rsa.pub ubuntu@hostname.com
$ sudo mkdir -p /app
$ sudo chown ubuntu:ubuntu /app
$ cd /app
$ tar xfz /home/ubuntu/hello_phoenix-0.0.1.tar.gz
```

## Making Our Application Public

We're getting close.

### Setting Up Our Init System

First step in exposing our application to the world is ensuring that our application will start running in case of a system restart - expected or unexpected. To do this, we will need to create an init script for our hosting environment's init system, be it `systemd`, `upstart`, or whatever.

Let's use `upstart` as an example. We'll edit our init script with `sudo vi /etc/init/my_app.conf` (this is on Ubuntu Linux).

```text
description "hello_phoenix"

## Uncomment the following two lines to run the
## application as www-data:www-data
#setuid www-data
#setgid www-data

start on runlevel [2345]
stop on runlevel [016]

expect stop
respawn

env MIX_ENV=prod
env PORT=8888
export MIX_ENV
export PORT


pre-start exec /bin/sh /app/bin/hello_phoenix start

post-stop exec /bin/sh /app/bin/hello_phoenix stop
```

Here, we've told `upstart` a few basic things about how we want it to handle our application. If you need to know how to do something in particular, take a look at the [`upstart` cookbook](http://upstart.ubuntu.com/cookbook/) for loads of information on it. We'll kick off the first start of our application with `sudo start hello_phoenix`.

One key point to notice is that we're instructing `upstart` to run our release's `bin/hello_phoenix start` command, which boostraps our application and runs it as a daemon.

### Setting Up Our Web Server

In a lot of cases, we're going to have more than one application running in our hosting environment, all of which might need to be accessible on port 80. Since only one application can listen on a single port at a time, we need to use something to proxy our application. Typically, Apache (with `mod_proxy` enabled) or nginx is used for this, and we'll be setting up nginx in this case.

Let's create our config file for our application. By default, everything in `/etc/nginx/sites-enabled` is included into the main `/etc/nginx/nginx.conf` file that is used to configure nginx's runtime environment. Standard practice is to create our file in `/etc/nginx/sites-available` and make a symbolic link to it in `/etc/nginx/sites-enabled`.

Note: These points hold true for Apache as well, but the steps to accomplish them are slightly different.

```console
$ sudo touch /etc/nginx/sites-available/hello_phoenix
$ sudo ln -s /etc/nginx/sites-available/hello_phoenix /etc/nginx/sites-enabled
$ sudo vi /etc/nginx/sites-available/hello_phoenix
```

These are the contents of our `/etc/nginx/sites-available/hello_phoenix` file.

```nginx
upstream hello_phoenix {
    server 127.0.0.1:8888;
}
server{
    listen 80;
    server_name .hostname.com;

    location / {
        try_files $uri @proxy;
    }

    location @proxy {
        include proxy_params;
        proxy_redirect off;
        proxy_pass http://hello_phoenix;
    }
}
```

Like our `upstart` script, this nginx config is basic. Look to the [nginx wiki](http://wiki.nginx.org/Main) for steps to configure any more involved features. Restart nginx with `sudo service nginx restart` to load our new config.

At this point, we should be able to see our application if we visit `http://hostname.com/` if everything has been successful up to this point.
