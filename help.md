Help: What to do when things go wrong:

Problem, you alreay have a version of Elixir greater than 0.14.2 installed on your system and compilation isn't working properly.

Solution, get an older version of elixir
You can follow the information from either of these for homebrew installed elixir, or follow the instructions for any alternate method you might have used.
https://gist.github.com/gcatlin/1847248
http://stackoverflow.com/questions/3987683/homebrew-install-specific-version-of-formula
NOTE: if you already have the older version installed, 'brew switch elixir 0.14.3' is what you need.

- make sure your version of hex matches your version of elixir
$ mix hex.local

- clean out all of your dependencies and re-get them
$ mix deps.clean --all
$ mix do deps.get