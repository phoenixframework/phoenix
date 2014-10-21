##Hello Phoenix!
The aim of this first guide is to get a phoenix application up and running on your system as quickly as possible.

Before we begin, you will need to install Elixir and Erlang on your machine. The Elixir site itself has the latest and most complete [installation information](http://elixir-lang.org/getting_started/1.html). Currently, Phoenix requires Elixir version 1.0.0 or greater which in turn requires Erlang version 17.0 or greater.

In order to install Phoenix, you will also need to have git installed on your system. While git is extremely popular, for those of you who may not have it installed, this is an important step. Github has some good documentation on [getting set up with git](https://help.github.com/articles/set-up-git).

Let's get started.

The first thing we need to do is clone the phoenix repo from github. Visit the Phoenix project's page on github: https://github.com/phoenixframework/phoenix

- First, clone the repo

    `git clone https://github.com/phoenixframework/phoenix.git`

- Then cd into the phoenix directory itself

    `cd phoenix`

- And make sure you are on the master branch.

    `git checkout master`

Once this is done, we need to have phoenix generate a new project for us, and we need  it to do so outside the phoenix repo itself. This is like running 'rails new my_project_name', in which rails will generate an empty project outside of the rails gem directory.

Phoenix will accept either absolute or relative paths for the directory of you new project. Both of these will work:

` $ mix phoenix.new hello_phoenix ../hello_phoenix`
` $ mix phoenix.new hello_phoenix /Users/me/work/elixir-stuff/hello_phoenix`

For our purposes, a relative path will do.

` $ mix phoenix.new hello_phoenix ../hello_phoenix`

The next step is to get and compile the dependencies that your phoenix application will need to run:

` $ mix do deps.get, compile`

Note: This is passing a list of arguments to mix and is functionally equivalent to the two line version.

` $ mix deps.get`

` $ mix compile`

After that, we start the application.

` $ mix phoenix.start`

Point your favorite web browser to localhost port 4000, and you should see the Phoenix Framework welcome page.
http://localhost:4000/  

![Phoenix Welcome Page](/images/welcome-to-phoenix.png)

If your screen looks like the image above, congratulations! You now have working Phoenix application.

Locally, your application is running in an iex session. To stop it, hit ctrl-c twice, just as you would to stop iex normally.

The next step is customizing the application just a bit to give you a sense of how a Phoenix is put together.
