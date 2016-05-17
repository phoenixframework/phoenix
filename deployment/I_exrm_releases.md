### What We'll Need

There are just a few things we'll need before we continue.

- a working application
- a build environment - this can be our dev environment
- a hosting environment - this can be our build environment for testing/experimentation

We need to be sure that the architectures for both our build and hosting environments are the same, e.g. 64-bit Linux -> 64-bit Linux. If the architectures don't match, our application might not run when deployed. Using a virtual machine that mirrors our hosting environment as our build environment is an easy way to avoid that problem.

### Goals

Our main goal for this guide is to generate a release, using the [Elixir Release Manager](https://github.com/bitwalker/exrm) (Exrm), and deploy it to our hosting environment. Once we have our application running, we will discuss steps needed to make it publicly visible.

## Tasks

Let's separate our release process into a few tasks so we can keep track of where we are.

- Add exrm as a dependency
- Generate a release
- Test it
- Deploy it
- Make it public

## Add exrm as a Dependency

To get started, we'll need to add `{:exrm, "~> 1.0"}` into the list of dependencies in our `mix.exs` file.

```elixir
  defp deps do
    [{:phoenix, "~> 1.1.0"},
     {:phoenix_ecto, "~> 2.0"},
     {:postgrex, ">= 0.0.0"},
     {:phoenix_html, "~> 2.3"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:cowboy, "~> 1.0"},
     {:exrm, "~> 1.0"}]
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
     applications: [:phoenix, :cowboy, :logger, :postgrex, :gettext,
                    :phoenix_ecto, :phoenix_html]]
  end
```

Doing this helps us overcome one of [exrm's common issues](https://hexdocs.pm/exrm/extra-common-issues.html) by helping exrm know about all our dependencies so that it can properly bundle them into our release. Without this, our application will probably alert us about missing modules or a failure to start a child application when we go to run our release.

Even if we list all of our dependencies, our application may still fail. Typically, this happens because one of our dependencies does not properly list its own dependencies. A quick fix for this is to include the missing dependency or dependencies in our list of applications. If this happens to you, and you feel like helping the community, you can create an issue or a pull request to that project's repo.

Within `config/prod.exs` we need to make two changes.   First we must configure our Endpoint to act as a server `server: true`.  Additionally we must set the root to be `.`.

```elixir
# Configures the endpoint
config :hello_phoenix, HelloPhoenix.Endpoint,
http: [port: 8888],
url: [host: "example.com"],
root: ".",
cache_static_manifest: "priv/static/manifest.json",
server: true
```

When we run `mix phoenix.server` to start our application, the `server` parameter is automatically set to true. When we're creating a release, however, we need to configure this manually. If we get through this release guide, and we aren't seeing any pages coming from our server, this is a likely culprit.

When generating a release and performing a hot upgrade, the static assets being served will not be the newest version without setting the root to `.`.  If you do not set root to `.` you will be forced to perform a restart so that the correct static assets are served, effectively changing the hot upgrade to a rolling restart.

If we take a quick look at our `config/prod.exs` again, we'll see that our port is set to `8888`.

```elixir
. . .
config :hello_phoenix, HelloPhoenix.Endpoint,
http: [port: 8888],
. . .
```

Alternately, we can set the port from an environment variable on our system.

```elixir
. . .
config :hello_phoenix, HelloPhoenix.Endpoint,
http: [port: {:system, "PORT"}],
. . .
```

If we don't currently have such an environment variable, we need to set it now, otherwise our release will not build properly.

There's one last thing to do before we create our release. We need to pre-compile our static assets using the `phoenix.digest` task. We will be generating a production release, so we need to run this task with `MIX_ENV=prod`.

```console
$ MIX_ENV=prod mix phoenix.digest
==> ranch (compile)
. . .
Check your digested files at 'priv/static'.
```

### Generating the Release

Now that we've configured our application, let's build our production release by running `MIX_ENV=prod mix release` at the root of our application.

```console
$ MIX_ENV=prod mix release

. . .

Generated hello_phoenix app
Consolidated Ecto.Queryable
Consolidated Phoenix.Param
Consolidated Phoenix.HTML.FormData
Consolidated Phoenix.HTML.Safe
Consolidated Plug.Exception
Consolidated Poison.Decoder
Consolidated Poison.Encoder
Consolidated Access
Consolidated Collectable
Consolidated Enumerable
Consolidated Inspect
Consolidated List.Chars
Consolidated Range.Iterator
Consolidated String.Chars
Consolidated protocols written to _build/prod/consolidated
==> Building release with MIX_ENV=prod.
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

- There are a number of lines which begin with "Consolidated". These are protocols which have been consolidated for faster function dispatch and better performance.

- We see our application's version number - `0.0.1`. This value comes from the application's `mix.exs` file. It is mapped to the `:version` key inside the `project/0` function.

- Exrm has created a `rel` directory at the root of our application where it has written everything related to this release.

Exrm uses a set of default configuration options when building our release that will work for most applications. If we need more advanced configuration options, we can checkout [exrm's configuration section](https://hexdocs.pm/exrm/extra-release-configuration.html#content) for more detailed information.

If we make a mistake, or if something doesn't go quite right, we can run `mix release.clean`, which will delete the release for the current application version number. If we add the `--implode` flag, exrm will remove _all_ releases for all versions of our application. These will be permanently removed unless they are under version control. Obviously, this is a destructive operation, and exrm will prompt us to make sure we want to continue.

#### Contents of a Release

Exrm has created our release, and put it somewhere in the `rel` directory, but where exactly did all the pieces end up?

Everything related to our releases is in the `rel/hello_phoenix` directory. Let's see what's in it.

```console
$ ls -la rel/hello_phoenix/
total 27216
drwxr-xr-x   7 lance  staff       238 May 13 18:47 .
drwxr-xr-x   3 lance  staff       102 May 13 18:47 ..
drwxr-xr-x   6 lance  staff       204 May 13 18:47 bin
drwxr-xr-x   8 lance  staff       272 May 13 18:47 erts-6.4
-rw-r--r--   1 lance  staff  13933031 May 13 18:47 hello_phoenix-0.0.1.tar.gz
drwxr-xr-x  26 lance  staff       884 May 13 18:47 lib
drwxr-xr-x   5 lance  staff       170 May 13 18:47 releases
```

The `bin` directory contains the generated executables for running our application. The `bin/hello_phoenix` executable is what we will use to issue commands to our application.

```console
$ ls -la rel/hello_phoenix/bin
total 80
drwxr-xr-x  6 lance  staff    204 May 13 18:47 .
drwxr-xr-x  7 lance  staff    238 May 13 18:47 ..
-rwxr-xr-x  1 lance  staff  13868 May 13 18:47 hello_phoenix
-rw-r--r--  1 lance  staff   4400 May 13 18:47 install_upgrade.escript
-rwxr-xr-x  1 lance  staff   5373 May 13 18:47 nodetool
-rw-r--r--  1 lance  staff   5283 Apr 18  2014 start_clean.boot
```

The `erts-6.4` directory contains all necessary files for the Erlang runtime system, pulled from our build environment.

```console
$ ls -la rel/hello_phoenix/erts-6.3/
total 8
drwxr-xr-x   8 lance  staff  272 May 13 18:47 .
drwxr-xr-x   7 lance  staff  238 May 13 18:47 ..
drwxr-xr-x  24 lance  staff  816 May 13 18:47 bin
drwxr-xr-x  12 lance  staff  408 May 13 18:47 include
drwxr-xr-x   5 lance  staff  170 May 13 18:47 lib
drwxr-xr-x   3 lance  staff  102 May 13 18:47 src
```

The `lib` directory contains the compiled BEAM files for our application and all of our dependencies. This is where all of our work goes.

```console
$ ls -la rel/hello_phoenix/lib/
otal 0
drwxr-xr-x  26 lance  staff  884 May 13 18:47 .
drwxr-xr-x   7 lance  staff  238 May 13 18:47 ..
drwxr-xr-x   3 lance  staff  102 May 13 18:47 compiler-5.0
drwxr-xr-x  16 lance  staff  544 May 13 18:47 consolidated
drwxr-xr-x   3 lance  staff  102 May 13 18:47 cowboy-1.0.0
drwxr-xr-x   4 lance  staff  136 May 13 18:47 cowlib-1.0.1
drwxr-xr-x   4 lance  staff  136 May 13 18:47 crypto-3.3
drwxr-xr-x   3 lance  staff  102 May 13 18:47 decimal-1.1.0
drwxr-xr-x   3 lance  staff  102 May 13 18:47 ecto-0.11.2
drwxr-xr-x   3 lance  staff  102 May 13 18:47 eex-1.0.4
drwxr-xr-x   3 lance  staff  102 May 13 18:47 elixir-1.0.4
drwxr-xr-x   4 lance  staff  136 May 13 18:47 hello_phoenix-0.0.1
drwxr-xr-x   3 lance  staff  102 May 13 18:47 iex-1.0.4
drwxr-xr-x   4 lance  staff  136 May 13 18:47 kernel-3.0
drwxr-xr-x   3 lance  staff  102 May 13 18:47 logger-1.0.4
drwxr-xr-x   4 lance  staff  136 May 13 18:47 phoenix-0.13.1
drwxr-xr-x   3 lance  staff  102 May 13 18:47 phoenix_ecto-0.4.0
drwxr-xr-x   3 lance  staff  102 May 13 18:47 phoenix_html-1.0.1
drwxr-xr-x   3 lance  staff  102 May 13 18:47 plug-0.12.2
drwxr-xr-x   3 lance  staff  102 May 13 18:47 poison-1.4.0
drwxr-xr-x   3 lance  staff  102 May 13 18:47 poolboy-1.5.1
drwxr-xr-x   3 lance  staff  102 May 13 18:47 postgrex-0.8.1
drwxr-xr-x   3 lance  staff  102 May 13 18:47 ranch-1.0.0
drwxr-xr-x   3 lance  staff  102 May 13 18:47 sasl-2.4
drwxr-xr-x   4 lance  staff  136 May 13 18:47 stdlib-2.0
drwxr-xr-x   3 lance  staff  102 May 13 18:47 syntax_tools-1.6.14
```

The `releases` directory is the home for our releases - any release-dependent configurations and scripts that Exrm finds necessary for running our application. If we have multiple versions of our application, and if we have created releases for them, we will have multiple releases in the `releases` directory.

```console
$ ls -la rel/hello_phoenix/releases/
total 16
drwxr-xr-x  5 lance  staff   170 May 13 18:47 .
drwxr-xr-x  7 lance  staff   238 May 13 18:47 ..
drwxr-xr-x  8 lance  staff   272 May 13 18:47 0.0.1
-rw-r--r--  1 lance  staff  1241 May 13 18:47 RELEASES
-rw-r--r--  1 lance  staff     9 May 13 18:47 start_erl.data
```

The `hello_phoenix-0.0.1.tar.gz` tarball in `rel/hello_phoenix/releases/0.0.1` is our release in archive form, ready to be shipped off to our hosting environment.

### Testing Our Release

Before deploying our release, we should make sure that it runs. To do that, we will issue the `console` command to our executable, essentially running our application via `iex`.

Note: Since we are building a production release - we set our mix environment to "prod" when we created it - we should exercise a little extra caution.

External dependencies will use their production configuration values. Applications will try to communicate with production databases, production Amazon S3 buckets, production message queues, and anything else which has a production configuration.

Some of these might be unreachable from the build environment, which will cause errors. Some might interact with important production data. Please be careful.

With a newly-generated application, though, we should be fine. :)

With all that in mind, let's start up a console.

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

This is the point where our application will crash if it fails to start a child application. If all goes well, however, we should end up at an `iex` prompt. We should also see our app running at [http://localhost:8888/](http://localhost:8888/).

Let's hit `ctrl-c` twice to get out of iex so that we can explore a couple of different ways to interact with our release.

One thing we can do is start the release without a console session. Let's try running the `start` command.

```console
$ rel/hello_phoenix/bin/hello_phoenix start
```
And we see . . . nothing except that our prompt comes right back. This is ok!

We can check to make sure that the release really is ok by pinging it.

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

Ok, let's get out of this session by hitting `ctrl-c` twice again. What happens if we ping the release now?

```console
$ rel/hello_phoenix/bin/hello_phoenix ping
pong
```

It's still alive and responding. This is a feature! If the server were to go down every time we stopped a remote console, that would be a problem. Note that this situation is different from when we ran the `console` command above. The `remote_console` command is not intended to start a release locally, but rather to connect to one which has already started.

So how _do_ we stop the server? There are two ways.

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

Let's use `upstart` as an example. We'll edit our init script with `sudo vi /etc/init/hello_phoenix.conf` (this is on Ubuntu Linux).

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
export MIX_ENV

## Uncomment the following two lines if we configured
## our port with an environment variable.
#env PORT=8888
#export PORT

## Add app HOME directory.
env HOME=/app
export HOME


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
# The following map statement is required
# if you plan to support channels. See https://www.nginx.com/blog/websocket-nginx/
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
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
        # The following two headers need to be set in order
        # to keep the websocket connection open. Otherwise you'll see
        # HTTP 400's being returned from websocket connections.
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
    }
}
```

Like our `upstart` script, this nginx config is basic. Look to the [nginx wiki](https://www.nginx.com/resources/wiki/) for steps to configure any more involved features. Restart nginx with `sudo service nginx restart` to load our new config.

At this point, we should be able to see our application if we visit `http://hostname.com/` if everything has been successful up to this point.
