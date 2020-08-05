# Up and Running

Let's get a Phoenix application up and running as quickly as possible.

Before we begin, please take a minute to read the [Installation Guide](installation.html). By installing any necessary dependencies beforehand, we'll be able to get our application up and running smoothly.

We can run `mix phx.new` from any directory in order to bootstrap our Phoenix application. Phoenix will accept either an absolute or relative path for the directory of our new project. Assuming that the name of our application is `hello`, let's run the following command:

```console
$ mix phx.new hello
```

> A note about [webpack](https://webpack.js.org/) before we begin: Phoenix will use webpack for asset management by default. Webpack's dependencies are installed via the node package manager, not mix. Phoenix will prompt us to install them at the end of the `mix phx.new` task. If we say "no" at that point, and if we don't install those dependencies later with `npm install`, our application will raise errors when we try to start it, and our assets may not load properly. If we don't want to use webpack at all, we can simply pass `--no-webpack` to `mix phx.new`.

> A note about [Ecto](ecto.html): Ecto allows our Phoenix application to communicate with a data store, such as PostgreSQL, MySQL, and others. If our application will not require this component we can skip this dependency by passing the `--no-ecto` flag to `mix phx.new`. This flag may also be combined with `--no-webpack` to create a skeleton application.

> To learn more about `mix phx.new` you can read the [Mix Tasks Guide](mix_tasks.html#phoenix-specific-mix-tasks).

```console
mix phx.new hello
* creating hello/config/config.exs
* creating hello/config/dev.exs
* creating hello/config/prod.exs
...
* creating hello/assets/static/images/phoenix.png
* creating hello/assets/static/favicon.ico

Fetch and install dependencies? [Yn]
```

Phoenix generates the directory structure and all the files we will need for our application. 

> Phoenix promotes the usage of git as version control software: among the generated files we find a `.gitignore`. We can `git init` our repository, and immediately add and commit all that hasn't been marked ignored. 

When it's done, it will ask us if we want it to install our dependencies for us. Let's say yes to that.

```console
Fetch and install dependencies? [Yn] Y
* running mix deps.get
* running mix deps.compile
* running cd assets && npm install && node node_modules/webpack/bin/webpack.js --mode development

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

> If you followed the [Installation Guide](installation.html) and opted to add `{:cowboy, "~> 2.7.0"}` to your mix.exs, go ahead and do that now and run `mix deps.get`.

Now we'll create our database:

```console
$ mix ecto.create
Compiling 13 files (.ex)
Generated hello app
The database for Hello.Repo has been created
```

In case the database could not be created, see the guides for the [`mix ecto.create`](mix_tasks.html#mix-ecto-create) for general trouble-shooting.

> Note: if this is the first time you are running this command, Phoenix may also ask to install Rebar. Go ahead with the installation as Rebar is used to build Erlang packages.

And finally, we'll start the Phoenix server:

```console
$ mix phx.server
[info] Running HelloWeb.Endpoint with cowboy 2.5.0 at http://localhost:4000

Webpack is watching the files…
...
```

If we choose not to have Phoenix install our dependencies when we generate a new application, the `mix phx.new` task will prompt us to take the necessary steps when we do want to install them.

```console
Fetch and install dependencies? [Yn] n

We are almost there! The following steps are missing:

    $ cd hello
    $ mix deps.get
    $ cd assets && npm install && node node_modules/webpack/bin/webpack.js --mode development

Then configure your database in config/dev.exs and run:

    $ mix ecto.create

Start your Phoenix app with:

    $ mix phx.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix phx.server
```

By default Phoenix accepts requests on port 4000. If we point our favorite web browser at [http://localhost:4000](http://localhost:4000), we should see the Phoenix Framework welcome page.

![Phoenix Welcome Page](assets/images/welcome-to-phoenix.png)

If your screen looks like the image above, congratulations! You now have a working Phoenix application. In case you can't see the page above, try accessing it via [http://127.0.0.1:4000](http://127.0.0.1:4000) and later make sure your OS has defined "localhost" as "127.0.0.1".

To stop it, we hit `ctrl-c` twice.

Now you are ready to explore the world provided by Phoenix! See [our community page](community.html) for books, screencasts, courses, and more.

Alternatively, you can continue reading these guides to have a quick introduction into all the parts that make your Phoenix application. If that's the case, you can read the guides in any order or start with our guide that explains the [Phoenix directory structure](directory_structure.html).

