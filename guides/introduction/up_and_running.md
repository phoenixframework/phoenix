# Up and Running

Let's get a Phoenix application up and running as quickly as possible.

Before we begin, please take a minute to read the [Installation Guide](installation.html). By installing any necessary dependencies beforehand, we'll be able to get our application up and running smoothly.

We can run `mix phx.new` from any directory in order to bootstrap our Phoenix application. Phoenix will accept either an absolute or relative path for the directory of our new project. Assuming that the name of our application is `hello`, let's run the following command:

```console
$ mix phx.new hello
```

> By default, `mix phx.new` includes a number of optional dependencies, for example:
>
> - [Ecto](ecto.html) for communicating with a data store, such as PostgreSQL, MySQL, and others. You can skip this with `--no-ecto`.
>
> - [Phoenix.HTML](https://hexdocs.pm/phoenix_html/Phoenix.HTML.html), [TailwindCSS](https://tailwindcss.com), and [Esbuild](https://esbuild.github.io) for HTML applications. You can skip them with the `--no-html` and `--no-assets` flags.
>
> - [Phoenix.LiveView](https://hexdocs.pm/phoenix_live_view/) for building realtime and interactive web applications. You can skip this with `--no-live`.
>
> Read the [Mix Tasks Guide](mix_tasks.html#phoenix-specific-mix-tasks) for the full list of things that can be excluded, among other options.

```console
mix phx.new hello
* creating hello/config/config.exs
* creating hello/config/dev.exs
* creating hello/config/prod.exs
...

Fetch and install dependencies? [Yn]
```

Phoenix generates the directory structure and all the files we will need for our application.

> Phoenix promotes the usage of git as version control software: among the generated files we find a `.gitignore`. We can `git init` our repository, and immediately add and commit all that hasn't been marked ignored.

When it's done, it will ask us if we want it to install our dependencies for us. Let's say yes to that.

```console
Fetch and install dependencies? [Yn] Y
* running mix deps.get
* running mix assets.setup
* running mix deps.compile

We are almost there! The following steps are missing:

    $ cd hello

Then configure your database in config/dev.exs and run:

    $ mix ecto.create

Start your Phoenix app with:

    $ mix phx.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix phx.server
```

Once our dependencies are installed, the task will prompt us to change into our project directory and start our application.

Phoenix assumes that our PostgreSQL database will have a `postgres` user account with the correct permissions and a password of "postgres". If that isn't the case, please see the [Mix Tasks Guide](mix_tasks.html#ecto-specific-mix-tasks) to learn more about the `mix ecto.create` task.

Ok, let's give it a try. First, we'll `cd` into the `hello/` directory we've just created:

```console
$ cd hello
```

Now we'll create our database:

```console
$ mix ecto.create
Compiling 13 files (.ex)
Generated hello app
The database for Hello.Repo has been created
```

In case the database could not be created, see the guides for the [`mix ecto.create`](mix_tasks.html#mix-ecto-create) for general troubleshooting.

> Note: if this is the first time you are running this command, Phoenix may also ask to install Rebar. Go ahead with the installation as Rebar is used to build Erlang packages.

And finally, we'll start the Phoenix server:

```console
$ mix phx.server
[info] Running HelloWeb.Endpoint with cowboy 2.9.0 at 127.0.0.1:4000 (http)
[info] Access HelloWeb.Endpoint at http://localhost:4000
[watch] build finished, watching for changes...
...
```

If we choose not to have Phoenix install our dependencies when we generate a new application, the `mix phx.new` task will prompt us to take the necessary steps when we do want to install them.

```console
Fetch and install dependencies? [Yn] n

We are almost there! The following steps are missing:

    $ cd hello
    $ mix deps.get

Then configure your database in config/dev.exs and run:

    $ mix ecto.create

Start your Phoenix app with:

    $ mix phx.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix phx.server
```

By default, Phoenix accepts requests on port 4000. If we point our favorite web browser at [http://localhost:4000](http://localhost:4000), we should see the Phoenix Framework welcome page.

![Phoenix Welcome Page](assets/images/welcome-to-phoenix.png)

If your screen looks like the image above, congratulations! You now have a working Phoenix application. In case you can't see the page above, try accessing it via [http://127.0.0.1:4000](http://127.0.0.1:4000) and later make sure your OS has defined "localhost" as "127.0.0.1".

To stop it, we hit `ctrl-c` twice.

Now you are ready to explore the world provided by Phoenix! See [our community page](community.html) for books, screencasts, courses, and more.

Alternatively, you can continue reading these guides to have a quick introduction into all the parts that make your Phoenix application. If that's the case, you can read the guides in any order or start with our guide that explains the [Phoenix directory structure](directory_structure.html).
