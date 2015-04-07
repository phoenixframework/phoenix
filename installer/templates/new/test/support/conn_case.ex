defmodule <%= application_module %>.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  imports other functionalities to make it easier
  to build and query models.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      use Phoenix.ConnTest
<%= if ecto do %>
      # Alias the data repository and import query/model functions
      alias <%= application_module %>.Repo
      import Ecto.Model
      import Ecto.Query, only: [from: 2]
<% end %>
      # Import URL helpers from the router
      import <%= application_module %>.Router.Helpers
    end
  end

  setup tags do
<%= if ecto do %>    unless tags[:async] do
      Ecto.Adapters.SQL.restart_test_transaction(<%= application_module %>.Repo, [])
    end
<% end %>
    :ok
  end
end
