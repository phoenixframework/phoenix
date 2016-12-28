defmodule <%= web_namespace %>.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

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
      alias <%= app_module %>.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
<% end %>

      # The default endpoint for testing
      @endpoint <%= endpoint_module %>
    end
  end

<%= if ecto do %>
  setup tags do
    <%= adapter_config[:test_setup] %>
    unless tags[:async] do
      <%= adapter_config[:test_async] %>
    end
    :ok
  end
<% else %>
  setup _tags do
    :ok
  end
<% end %>
end
