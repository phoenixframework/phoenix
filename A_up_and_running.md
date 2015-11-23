The aim of this first guide is to get a Phoenix application up and running as quickly as possible.

Before we begin, please take a minute to read the [Installation Guide](http://www.phoenixframework.org/docs/installation). By installing any necessary dependencies beforehand, we'll be able to get our application up and running smoothly.

At this point, we should have Elixir, Erlang, Hex, and the Phoenix archive installed. We should also have PostgreSQL and node.js installed to build a default application.

Ok, we're ready to go!

We can run `mix phoenix.new` from any directory in order to bootstrap our Phoenix application. Phoenix will accept either an absolute or relative path for the directory of our new project. Assuming that the name of our application is `hello_phoenix`, either of these will work.

```console
$ mix phoenix.new /Users/me/work/elixir-stuff/hello_phoenix
```

```console
$ mix phoenix.new hello_phoenix
```

> A note about [Brunch.io](http://brunch.io/) before we begin: Phoenix will use Brunch.io for asset management by default. Brunch.io's dependencies are installed via the node package manager, not mix. Phoenix will prompt us to install them at the end of the `mix phoenix.new` task. If we say "no" at that point, and if we don't install those dependencies later with `npm install`, our application will raise errors when we try to start it, and our assets may not load properly. If we don't want to use Brunch.io at all, we can simply pass `--no-brunch` to `mix phoenix.new`.

Now that we're ready, let's run `mix phoenix.new` with a relative path.

```console
mix phoenix.new hello_phoenix
* creating hello_phoenix/config/config.exs
* creating hello_phoenix/config/dev.exs
* creating hello_phoenix/config/prod.exs
...
* creating hello_phoenix/web/views/layout_view.ex
* creating hello_phoenix/web/views/page_view.ex

Fetch and install dependencies? [Yn]
```

Phoenix generates the directory structure and all the files we will need for our application. When it's done, it will ask us if we want it to install our dependencies for us. Let's say yes to that.

```console
Fetch and install dependencies? [Yn] y
* running npm install && node node_modules/brunch/bin/brunch build
* running mix deps.get

We are all set! Run your Phoenix application:

    $ cd hello_phoenix
    $ mix ecto.create
    $ mix phoenix.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix phoenix.server
```

Once our dependencies are installed, the task will prompt us to change into our project directory and start our application.

Phoenix assumes that our PostgreSQL database will have a `postgres` user account with the correct permissions and a password of "postgres". If that isn't the case, please see the instructions for the [ecto.create](http://www.phoenixframework.org/docs/mix-tasks#section--ecto-create-) mix task.

Ok, let's give it a try. First, we'll `cd` into the `hello_phoenix/` directory we've just created:

    $ cd hello_phoenix

Now we'll create our database:

```
$ mix ecto.create
The database for HelloPhoenix.Repo has been created.
```

And finally, we'll start the Phoenix server:

```console
$ mix phoenix.server
[info] Running HelloPhoenix.Endpoint with Cowboy on http://localhost:4000
23 Nov 05:25:14 - info: compiled 5 files into 2 files, copied 3 in 1724ms
```

> Note: if this is the first time you are running this command, Phoenix may also ask to install Rebar. Go ahead with the installation as Rebar is used to build Erlang packages.

If we choose not to have Phoenix install our dependencies when we generate a new application, the `phoenix.new` task will prompt us to take the necessary steps when we do want to install them.

```console
Fetch and install dependencies? [Yn] n

Phoenix uses an optional assets build tool called brunch.io
that requires node.js and npm. Installation instructions for
node.js, which includes npm, can be found at http://nodejs.org.

After npm is installed, install your brunch dependencies by
running inside your app:

    $ npm install

If you don't want brunch.io, you can re-run this generator
with the --no-brunch option.


We are all set! Run your Phoenix application:

    $ cd hello_phoenix
    $ mix deps.get
    $ mix ecto.create
    $ mix phoenix.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix phoenix.server
```

By default Phoenix accepts requests on port 4000. If we point our favorite web browser at [http://localhost:4000](http://localhost:4000), we should see the Phoenix Framework welcome page.

![Phoenix Welcome Page](/images/welcome-to-phoenix.png)

If your screen looks like the image above, congratulations! You now have a working Phoenix application. In case you can't see the page above, try accessing it via [http://127.0.0.1:4000](http://127.0.0.1:4000) and later make sure your OS has defined "localhost" as "127.0.0.1".

Locally, our application is running in an iex session. To stop it, we hit ctrl-c twice, just as we would to stop iex normally.

The next step is customizing our application just a bit to give us a sense of how a Phoenix app is put together.
