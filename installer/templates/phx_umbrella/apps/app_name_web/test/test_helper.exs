ExUnit.start

Mix.Task.run "ecto.create", ~w(-r Chirp.Web.Repo --quiet)
Mix.Task.run "ecto.migrate", ~w(-r Chirp.Web.Repo --quiet)
Ecto.Adapters.SQL.begin_test_transaction(Chirp.Web.Repo)
