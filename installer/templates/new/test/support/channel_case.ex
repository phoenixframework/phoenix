defmodule <%= application_module %>.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  imports other functionality to make it easier
  to build and query models.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      use Phoenix.ChannelTest
<%= if ecto do %>
      # Alias the data repository and import query/model functions
      alias <%= application_module %>.Repo
      import Ecto.Model
      import Ecto.Query, only: [from: 2]
<% end %>

      # The default endpoint for testing
      @endpoint <%= application_module %>.Endpoint
    end
  end

  setup_all do
    @endpoint.start_link()
    :ok
  end

  setup tags do
<%= if ecto do %>    unless tags[:async] do
      Ecto.Adapters.SQL.restart_test_transaction(<%= application_module %>.Repo, [])
    end
<% end %>
    :ok
  end
end
