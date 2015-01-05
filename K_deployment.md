## Deployment

Once we have a working application, we're ready to deploy it. If you're not quite finished with your own application, don't worry. Just follow the [Up and Running Guide](http://www.phoenixframework.org/v0.7.2/docs/up-and-running) to create a basic application to work with.

### What We'll Need

Deployment is great and all, but be sure you have these things before continuing:

- a working application
- a build environment - this can be your dev env
- a hosting environment - this can also be your build env for testing/experimentation

Be sure that the architectures for both your build and hosting environments are the same, e.g. 64-bit Linux -> 64-bit Linux. If the architectures don't match, your application might not run when deployed. Using a virtual machine for your build environment that mirrors your hosting environment is an easy way to avoid such problems.

### Goals

Our main goal for this guide is to generate a release, using [Elixir Release Manager](https://github.com/bitwalker/exrm) (exrm) and deploy it to our hosting environment. Once we have our application running, we will discuss steps needed to make it available to the world.

## Tasks

Let's separate our release process into a few tasks so we can keep track of where we are.

- Add exrm as a dependency
- Generate a release
- Deploy our release
- Expose our application

## Add exrm as a Dependency

To get started, we'll need to add `{:exrm, "~> 0.14.16"}` into the list of dependencies in our `mix.exs` file.

```elixir
  def deps do
    [{:phoenix, "~> 0.7.2"},
      {:cowboy, "~> 1.0.0"},
      {:exrm, "~> 0.14.16"}]
  end
```

With that taken care of, a simple `mix do deps.get, compile` will pull down exrm and its dependencies, along with the rest of our application's dependencies, and ensures that everything compiles. If all goes well, exrm's mix tasks will be available as well.

```console
$ mix help
. . .
mix release           # Build a release for the current mix application.
mix release.clean     # Clean up any release-related files.
mix release.plugins   # View information about active release plugins
. . .
```

### Configure Our Applications

Now we need to update our `mix.exs` file to have all dependencies listed in the `applications` list in the `application/0` function.

```elixir
  def application do
    [mod: {HelloPhoenix, []},
      applications: [:phoenix, :cowboy, :logger]]
  end
```

Doing this helps us overcome one of [exrm's common issues](https://github.com/bitwalker/exrm#common-issues) by helping exrm know of all our dependencies so that it can properly bundle them into our release. Without this, our application will probably alert us about missing modules or a failure to start a child application when we go to run our release.

Even if we list all of our dependencies, our application may still fail. Typically, this happens because one of our dependencies does not properly list its own dependencies. A quick fix for this is to include the missing dependency or dependencies in our list of applications. If you feel like helping the community, you can create an issue or a pull request to that project's repo, but it isn't necessary.

In our `lib/hello_phoenix.ex` file, we need to start our endpoint as part of the `start/2` function.

```elixir
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    HelloPhoenix.Endpoint.start

    children = [
      # Define workers and child supervisors to be supervised
      # worker(MyApp.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

Note: Just to be extra clear, this file is named after our application. If we had called it `MyApp`, this file would be `lib/my_app.ex`.

#### A Note about `mix phoenix.start`

Once we add the `HelloPhoenix.Endpoint.start` to the `start/2` function, `mix phoenix.start` will no longer work, and we'll get an error if we try to run it.

```text
$ mix phoenix.start
Running HelloPhoenix.Endpoint with Cowboy on port 4000 (http)
** (RuntimeError) Something went wrong while starting endpoint: already started: #PID<0.139.0>
   (phoenix) lib/phoenix/endpoint/adapter.ex:122: Phoenix.Endpoint.Adapter.report/4
   (phoenix) lib/phoenix/endpoint/adapter.ex:82: Phoenix.Endpoint.Adapter.start/2
   (elixir) lib/enum.ex:537: Enum."-each/2-lists^foreach/1-0-"/2
   (elixir) lib/enum.ex:537: Enum.each/2
   (phoenix) lib/mix/tasks/phoenix.start.ex:17: Mix.Tasks.Phoenix.Start.run/1
   (mix) lib/mix/cli.ex:55: Mix.CLI.run_task/2
```

This error is telling us that `mix phoenix.start` has tried to start our endpoint twice. Here's what's happening. Invoking `mix` will always start our application, and starting our application will, of course, start our endpoint. Since we added the `HelloPhoenix.Endpoint.start` line to the `start/2` function, running the `phoenix.start` task will attempt to start the endpoint again, causing the error.

How do we start our application in development, once we've modified the `start/2` function? The short answer is that we can just run `iex -S mix`. This will start our application and keep it running. It has a nice advantage in that we can also interact with the running application this way.

```console
$ iex -S mix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Running HelloPhoenix.Endpoint with Cowboy on port 4000 (http)
Interactive Elixir (1.0.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)>
```

If we go to [http://localhost:4000/](http://localhost:4000), we should see our familiar welcome page.

As a side note, if we try to simply run `mix`, our application will start, but unfortunately, it will halt again immediately.

```console
$ mix
Running HelloPhoenix.Endpoint with Cowboy on port 4000 (http)
$
```

### Generating the release

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
- Since we didn't specify a `MIX_ENV` value, we got `dev` by default. Right now, we're experimenting. If we were doing a real release, we would want to specify `MIX_ENV=prod`.

- We see our application's version number - `0.0.1`. This value comes from the application's `mix.exs` file. It is mapped to the `:version` key inside the `project/0` function.

- Exrm has created a `rel` directory at the root of our application where it has written everything related to this release.

Exrm uses a set of default configuration options when building our release that will work for most applications. If you need more advanced configuration options, checkout [exrm's configuration section](https://github.com/bitwalker/exrm#configuration) for more detailed information.

If we make a mistake, or if something doesn't go quite right, we can run `mix release.clean`, which will delete the release for the current application version number. If we add the `--implode` flag, expm will remove _all_ releases. These will be permanently removed unless they are under version controll. Obviously, this is a destructive operation, and expm will prompt us to make sure we want to continue.

#### Contents of a Release

Exrm has created our release, but you may be asking yourself, "Where is it? What is this `rel` directory?" Let's take a look.

Everything related to releases is in the `rel` directory. Let's see what's in it.

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

The `bin` directory contains our generated executables for running our application. The `bin/hello_phoenix` executable is what we will eventually use to issue commands to our application.

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

The `lib` directory contains the compiled BEAM files for our application and all of our dependencies. This is where all of your hard work goes.

```console
$ ls -la rel/hello_phoenix/lib/
total 0
drwxr-xr-x  19 lance  staff  646 Jan  4 14:16 .
drwxr-xr-x   7 lance  staff  238 Jan  4 14:16 ..
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 compiler-5.0.3
drwxr-xr-x  13 lance  staff  442 Jan  4 14:16 consolidated
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 cowboy-1.0.0
drwxr-xr-x   4 lance  staff  136 Jan  4 14:16 cowlib-1.0.1
drwxr-xr-x   4 lance  staff  136 Jan  4 14:16 crypto-3.4.2
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 elixir-1.0.2
drwxr-xr-x   4 lance  staff  136 Jan  4 14:16 hello_phoenix-0.0.1
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 iex-1.0.2
drwxr-xr-x   4 lance  staff  136 Jan  4 14:16 kernel-3.1
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 logger-1.0.2
drwxr-xr-x   4 lance  staff  136 Jan  4 14:16 phoenix-0.7.2
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 plug-0.9.0
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 poison-1.3.0
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 ranch-1.0.0
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 sasl-2.4.1
drwxr-xr-x   4 lance  staff  136 Jan  4 14:16 stdlib-2.3
drwxr-xr-x   3 lance  staff  102 Jan  4 14:16 syntax_tools-1.6.17
```

The `releases` directory is the home for our releases, being used to house any release-dependent configurations and scripts that Exrm finds necessary for running our application. If we have multiple versions of our application, and if we have created releases for them, we will have multiple releases in the `releases` directory.

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

### Testing our release

Before deploying our release, we should make sure that it runs on our build environment. To do that, we will issue the `console` command to our executable, essentially running our application via `iex`.

```console
$ rel/hello_phoenix/bin/hello_phoenix console
Exec: /Users/lance/lance-work/hello_phoenix/rel/hello_phoenix/erts-6.3/bin/erlexec -boot /Users/lance/lance-work/hello_phoenix/rel/hello_phoenix/releases/0.0.1/hello_phoenix -boot_var ERTS_LIB_DIR /Users/lance/lance-work/hello_phoenix/rel/hello_phoenix/erts-6.3/../lib -env ERL_LIBS /Users/lance/lance-work/hello_phoenix/rel/hello_phoenix/lib -config /Users/lance/lance-work/hello_phoenix/rel/hello_phoenix/releases/0.0.1/sys.config -pa /Users/lance/lance-work/hello_phoenix/rel/hello_phoenix/lib/consolidated -args_file /Users/lance/lance-work/hello_phoenix/rel/hello_phoenix/releases/0.0.1/vm.args -user Elixir.IEx.CLI -extra --no-halt +iex -- console
Root: /Users/lance/lance-work/hello_phoenix/rel/hello_phoenix
/Users/lance/lance-work/hello_phoenix/rel/hello_phoenix
Erlang/OTP 17 [erts-6.3] [source] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Running HelloPhoenix.Endpoint with Cowboy on port 4000 (http)
Interactive Elixir (1.0.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(hello_phoenix@127.0.0.1)1>

```

This is the point where your application will crash if it fails to start a child application. However, if all goes well, you should be dropped into an `iex` prompt. We should also see our app running at [http://localhost:4000/](http://localhost:4000/).

Congratulations! We're ready to deploy our application!

## Deploy!

Now comes the easy part! There are many ways for us to get our tarballed release to our hosting environment, so you have a bit of free reign in this step.

In our example, we'll use SCP to upload to a remote server.

```console
$ scp -i ~/.ssh/id_rsa.pub rel/hello_phoenix-0.0.1.tar.gz ubuntu@hostname.com:/home/ubuntu
hello_phoenix-0.0.1.tar.gz                100%   18MB  80.0KB/s   03:48
```

Hooray! Let's SSH into that environment to set our application up.

```console
$ ssh -i ~/.ssh/id_rsa.pub ubuntu@hostname.com
$ sudo mkdir -p /app
$ sudo chown ubuntu:ubuntu /app
$ cd /app
$ tar xfz /home/ubuntu/hello_phoenix-0.0.1.tar.gz
```

See? I told you it would be easy.

## Exposè

We're getting close.

### Set up our init system

First step in exposing our application to the world is ensuring that our application is running in case of a system restart, expected or unexpected. To do this, we will need to create an init script for our hosting environment's init system, be it `systemd`, `upstart`, or whatever.

In this case, we'll be using `upstart` as our OS is Ubuntu, and `upstart` has been bundled with Ubuntu since 6.10. Let's edit our init script with `sudo vi /etc/init/my_app.conf`

```text
description "hello_phoenix"

## Uncomment the following two lines to run the
## application as www-data:www-data
#setuid www-data
#setgid www-data

start on startup
stop on shutdown

respawn

env MIX_ENV=prod
env PORT=8888
export MIX_ENV
export PORT

exec /bin/sh /app/bin/hello_phoenix start
```

Here, we've told `upstart` a few basic things about how we want it to handle our application. If you need to know how to do somthing in particular, take a look at the [`upstart` cookbook](http://upstart.ubuntu.com/cookbook/) for loads of information on it. We'll kick off the first start of our application with `sudo start hello_phoenix`.

One key point to notice is that we're instructing `upstart` to run our release's `bin/hello_phoenix start` command, which boostraps our application and runs it as a daemon.

#### exrm commands

Along with the `start` command, exrm bundles a few others with our application that are equally useful. Check out the [exrm docs](https://github.com/bitwalker/exrm) for details on what's possible.

##### `ping`

The `ping` command is a great sanity check when you need to ensure your application is running:

```console
$ bin/hello_phoenix ping
pong
```

Or to see if it isn't:

```console
$ bin/hello_phoenix ping
Node 'hello_phoenix@127.0.0.1' not responding to pings.
```

##### `remote_console`

`remote_console` will be your friend when debugging is in order. It allows you to attach an IEx console to your running application. When closing the console, your application continues to run.

```console
$ bin/hello_phoenix remote_console
Erlang/OTP 17 [erts-6.1] [source-d2a4c20] [64-bit] [smp:4:4] [async-threads:10] [hipe] [kernel-poll:false]

Interactive Elixir (0.15.2-dev) - press Ctrl+C to exit (type h() ENTER for help)
iex(hello_phoenix@127.0.0.1)1>
```

##### `upgrade`

The `upgrade` command allows you to upgrade your application to a newer codebase without downtime.

##### `stop`

You may run into situations where your application needs to stop. Look no further than the `stop` command.

```console
$ bin/hello_phoenix stop
ok
```

### Set up our web server

In a lot of cases, you're going to have more than one application running in your hosting environment, all of which might need to be accessible on port 80. Since only one application can listen on a single port at a time, we need to use something to proxy our application. You will typically see Apache (with `mod_proxy` enabled) or nginx used for this, and we'll be setting up nginx in this case.

Let's create our config file for our application. By default, everything in `/etc/nginx/sites-enabled` is included into the main `/etc/nginx/nginx.conf` file that is used to configure nginx's runtime environment. Standard practice is to create our file in `/etc/nginx/sites-available` and make a symbolic link to it in `/etc/nginx/sites-enabled`.

Note: These points hold true for Apache as well, but the steps to accomplish them are slightly different.

```console
$ sudo touch /etc/nginx/sites-available/hello_phoenix
$ sudo ln -s /etc/nginx/sites-available /etc/nginx/sites-enabled
$ sudo vi /etc/nginx/sites-available/hello_phoenix
```

Contents of our `/etc/nginx/sites-available/hello_phoenix` file:

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
