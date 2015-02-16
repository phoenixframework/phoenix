The aim of this first guide is to get a Phoenix application up and running as quickly as possible.

Before we begin, we will need to install Elixir and Erlang. The Elixir site itself has the latest and most complete [installation information](http://elixir-lang.org/getting_started/1.html). Currently, Phoenix requires Elixir version 1.0.0 or greater which in turn requires Erlang version 17.0 or greater.

In order to install Phoenix, we will also need to have git installed on our system. While git is extremely popular, for those of us who may not have it installed, this is an important step. Github has some good documentation on [getting set up with git](https://help.github.com/articles/set-up-git).

Let's get started.

The first thing we need to do is clone the Phoenix repo from github. Let's navigate into a directory that we want to contain Phoenix. Cloning the repo will create a new directory called `phoenix` wherever we run the clone command. Here are the steps.

- First, clone the repo
```console
$ git clone https://github.com/phoenixframework/phoenix.git
```

- Then cd into the phoenix directory itself
```console
$ cd phoenix
```

- And make sure we are on the v0.9.0 branch.
```console
$ git checkout v0.9.0
```

- Get the dependencies and compile the whole project
```console
$ mix do deps.get, compile
```
Note: This is passing a list of arguments to mix and is functionally equivalent to the two line version.

```console
$ mix deps.get
```

```console
$ mix compile
```
Note: On some Linux systems, Erlang installations do not include the Erlang ssl or inets packages. This will cause hex to fail. If you see an error message like this one,

```console
$  mix do deps.get, compile
Could not start Hex. Try fetching a new version with `mix local.hex` or uninstalling it with `mix archive.uninstall hex.ez`
** (UndefinedFunctionError) undefined function: :ssl.start/0 (module :ssl is not available)
:ssl.start()
lib/hex.ex:16: Hex.start_api/0
lib/hex.ex:8: Hex.start/0
(mix) lib/mix/tasks/local.hex.ex:69: Mix.Tasks.Local.Hex.start/0
(mix) lib/mix/dep/loader.ex:117: Mix.Dep.Loader.with_scm_and_app/1
(mix) lib/mix/dep/loader.ex:86: Mix.Dep.Loader.to_dep/3
(elixir) lib/enum.ex:977: Enum."-map/2-lc$^0/1-0-"/2
(mix) lib/mix/dep/loader.ex:234: Mix.Dep.Loader.mix_children/1
```
(note this part especially `(module :ssl is not available)`), try installing those packages manually. Of course, substitute the package manager for your system if it doesn't use apt as the example does.

```console
$ sudo apt-get install erlang-ssl
$ sudo apt-get install erlang-inets
```
Once this is done, we need to have Phoenix generate a new project for us, and we need it to do so outside the Phoenix repo itself. Phoenix provides a mix task `phoenix.new` for this, and the task takes both the name of our new project and the path to where we want  the new application to live.

Phoenix will accept either an absolute or relative path for the directory of our new project. Either of these will work.

```console
$ mix phoenix.new hello_phoenix /Users/me/work/elixir-stuff/hello_phoenix
```

```console
$ mix phoenix.new hello_phoenix ../hello_phoenix
```

For our purposes, a relative path will do.

```console
$ mix phoenix.new hello_phoenix ../hello_phoenix
```

We can then `cd` into the new project directory.

```console
$ cd ../hello_phoenix
```

The next step is to get and compile the dependencies that our phoenix application will need.

```console
$ mix do deps.get, compile
```
This is different from the similar step we did above. That step was compiling Phoenix itself. This is compiling our new application, which Phoenix just generated.

Once the application compiles successfully, we can start it.

```console
$ mix phoenix.server
```

By default Phoenix accepts requests on port 4000. If we point our favorite web browser at [http://localhost:4000](http://localhost:4000), we should see the Phoenix Framework welcome page.

![Phoenix Welcome Page](/images/welcome-to-phoenix.png)

If your screen looks like the image above, congratulations! You now have working Phoenix application.

Locally, our application is running in an iex session. To stop it, we hit ctrl-c twice, just as we would to stop iex normally.

The next step is customizing our application just a bit to give us a sense of how a Phoenix app is put together.
