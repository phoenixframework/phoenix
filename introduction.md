Welcome to Phoenix!

Phoenix is a web development framework written in Elixir which implements the server-side MVC pattern. If you've ever used another such framework, say Ruby on Rails or Django, many of the concepts will be familiar to you. Phoenix is not, however, simply a Rails clone. It has some interesting new twists, including sockets, and the potential for alternative architectures - should you choose to implement them - which make services more manageable from the very beginning of your project.

If you are already familiar with Elixir, great! If not, there are a number of places you can go to learn. You might want to have a read through the Elixir guides first [LINK http://elixir-lang.org/getting_started/1.html], or you might want to read through any of the fine books now available on Elixir [LINK http://pragprog.com/book/elixir/programming-elixir] [LINK http://shop.oreilly.com/product/0636920030584.do] [LINK http://www.manning.com/juric/]

Before we begin, you will need to install Elixir and Erlang on your machine. The Elixir site itself has the latest and most complete installation information. [LINK http://elixir-lang.org/getting_started/1.html] At the time these guides are being writtin, Elixir is moving very rapidly, sometimes with breaking changes. Until the language reaches 1.0, getting the version number exactly correct will be important. Currently, Phoenix requires Elixir version 0.14.2 which in turn requires Erlang version 17.0.

In order to install Phoenix, you will need to have git installed on your system as well. While git is extremely popular, for those of you who may not have it installed, this is an important step. Github has some good documentation on getting set up with git. [LINK https://help.github.com/articles/set-up-git]

Hello Phoenix!
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
~/work/elixir-stuff/phoenix$ mix phoenix.new hello_phoenix ../hello_phoenix
# lots of output redacted
Generated phoenix.app
* creating ../hello_phoenix
* creating ../hello_phoenix/.gitignore
* creating ../hello_phoenix/README.md
* creating ../hello_phoenix/lib
* creating ../hello_phoenix/lib/hello_phoenix
* creating ../hello_phoenix/lib/hello_phoenix.ex
* creating ../hello_phoenix/lib/hello_phoenix/config
* creating ../hello_phoenix/lib/hello_phoenix/config/config.ex
* creating ../hello_phoenix/lib/hello_phoenix/config/dev.ex
* creating ../hello_phoenix/lib/hello_phoenix/config/prod.ex
* creating ../hello_phoenix/lib/hello_phoenix/config/test.ex
* creating ../hello_phoenix/lib/hello_phoenix/controllers
* creating ../hello_phoenix/lib/hello_phoenix/controllers/pages.ex
* creating ../hello_phoenix/lib/hello_phoenix/router.ex
* creating ../hello_phoenix/lib/hello_phoenix/supervisor.ex
* creating ../hello_phoenix/lib/hello_phoenix/templates
* creating ../hello_phoenix/lib/hello_phoenix/templates/layouts
* creating ../hello_phoenix/lib/hello_phoenix/templates/layouts/application.html.eex
* creating ../hello_phoenix/lib/hello_phoenix/templates/pages
* creating ../hello_phoenix/lib/hello_phoenix/templates/pages/index.html.eex
* creating ../hello_phoenix/lib/hello_phoenix/views
* creating ../hello_phoenix/lib/hello_phoenix/views.ex
* creating ../hello_phoenix/lib/hello_phoenix/views/layouts.ex
* creating ../hello_phoenix/lib/hello_phoenix/views/pages.ex
* creating ../hello_phoenix/mix.exs
* creating ../hello_phoenix/priv
* creating ../hello_phoenix/priv/static
* creating ../hello_phoenix/priv/static/css
* creating ../hello_phoenix/priv/static/css/.gitkeep
* creating ../hello_phoenix/priv/static/css/app.css
* creating ../hello_phoenix/priv/static/images
* creating ../hello_phoenix/priv/static/images/.gitkeep
* creating ../hello_phoenix/priv/static/js
* creating ../hello_phoenix/priv/static/js/phoenix.js
* creating ../hello_phoenix/test
* creating ../hello_phoenix/test/hello_phoenix_test.exs
* creating ../hello_phoenix/test/test_helper.exs

- The next step is to get and compile the dependencies that your phoenix application will need to run:
mix do deps.get, compile

If you have any problems during compilation, please see the help page. [LINK help.md]

- And after that, we run mix phoenix.start
~/work/elixir-stuff/hello_phoenix$ mix phoenix.start
# lots of output redacted
Generated hello_phoenix.app
Running Elixir.HelloPhoenix.Router with Cowboy on port 4000
GET: []
GET: ["favicon.ico"]

- Point your favorite web browser to localhost port 4000, and you should see the Phoenix Framework welcome page.
http://localhost:4000/  # [IMAGE include a screenshot of the page here]

If your screen looks like the image above, congratulations! You now have working Phoenix application.