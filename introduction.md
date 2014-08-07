##Welcome to Phoenix!

Phoenix is a web development framework written in Elixir which implements the server-side MVC pattern. If you've ever used a similar framework, say Ruby on Rails or Django, many of the concepts will be familiar to you. Phoenix is not, however, simply a Rails clone. It has some interesting new twists, including sockets, pre-compiled templates and the potential for alternative architectures - should you choose to implement them - which make services more manageable from the very beginning of your project.

If you are already familiar with Elixir, great! If not, there are a number of places you can go to learn. You might want to have a read through the Elixir guides first [LINK http://elixir-lang.org/getting_started/1.html]. You might also want to look through any of the books, blogs or videos listed in the resource page. [LINK resources.md]

Before we begin, you will need to install Elixir and Erlang on your machine. The Elixir site itself has the latest and most complete installation information. [LINK http://elixir-lang.org/getting_started/1.html] At the time these guides are being written, Elixir is moving very rapidly, sometimes with breaking changes. Until the language reaches 1.0, getting the version number exactly correct will be important. Currently, Phoenix requires Elixir version 0.14.2 which in turn requires Erlang version 17.0 or greater.

In order to install Phoenix, you will also need to have git installed on your system. While git is extremely popular, for those of you who may not have it installed, this is an important step. Github has some good documentation on getting set up with git. [LINK https://help.github.com/articles/set-up-git]

##Hello Phoenix!
The purpose of this first guide is to get a phoenix application up and running on your system as quickly as possible.

Let's get started.

The first thing we need to do is clone the phoenix repo from github. Visit the Phoenix project's page on github [LINK https://github.com/phoenixframework/phoenix]
[SHOW command and output]
- First, clone the repo
git clone https://github.com/phoenixframework/phoenix.git

- Then cd into the phoenix directory itself
cd phoenix

- And checkout the latest release version
git checkout v0.3.0

Once this is done, we need to have phoenix generate a new project for us, and we need  it to do so outside the phoenix repo itself. This is like running 'rails new my_project_name', in which rails will generate an empty project outside of the rails gem directory.

Phoenix will accept either absolute or relative paths for the directory of you new project. Both of these will work:
$ mix phoenix.new hello_phoenix ../hello_phoenix
$ mix phoenix.new hello_phoenix /Users/me/work/elixir-stuff/hello_phoenix

[SHOW command and output]
$ mix phoenix.new hello_phoenix ../hello_phoenix
This will produce a lot of output, but you should not see any errors.


- The next step is to get and compile the dependencies that your phoenix application will need to run:
$ mix do deps.get, compile
Note: This is passing a list of arguments to mix and is functionally equivalent to the two line version
$ mix deps.get
$ mix compile

If you have any problems during compilation, please see the help page. [LINK help.md]

After that, we start the application.
$ mix phoenix.start
~/work/elixir-stuff/hello_phoenix$ mix phoenix.start
<lots of output redacted>
Generated hello_phoenix.app
Running Elixir.HelloPhoenix.Router with Cowboy on port 4000
GET: []
GET: ["favicon.ico"]

Point your favorite web browser to localhost port 4000, and you should see the Phoenix Framework welcome page.
http://localhost:4000/  # [IMAGE include a screenshot of the page here]

If your screen looks like the image above, congratulations! You now have working Phoenix application.

Locally, your application is running in an iex session. To stop it, hit ctrl-c twice, just as you would to stop iex normally.

The next step is customizing the application just a bit to give you a sense of how a Phoenix is put together. [LINK to a-bit-more.md]
