Help: What to do when things go wrong.

Problem: You already have a version of Elixir greater than 0.14.2 installed on your system and compilation isn't working properly.

Solution: Get an older version of Elixir and re-compile your dependencies.
For homebrew installed elixir, you can follow either of the following links. Otherwise follow the instructions for any alternate method you might have used to install Elixir.
https://gist.github.com/gcatlin/1847248
http://stackoverflow.com/questions/3987683/homebrew-install-specific-version-of-formula
NOTE: if you already have the older version installed, 'brew switch elixir 0.14.3' is what you need.

- make sure your version of hex matches your version of elixir
$ mix hex.local

- clean out all of your dependencies and re-get them
$ mix deps.clean --all
$ mix do deps.get, compile
