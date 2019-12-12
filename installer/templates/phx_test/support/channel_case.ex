defmodule <%= web_namespace %>.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use <%= web_namespace %>.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      use Phoenix.ChannelTest

      # The default endpoint for testing
      @endpoint <%= endpoint_module %>
    end
  end<%= if ecto do %>

  setup tags do
    <%= adapter_config[:test_setup] %>

    unless tags[:async] do
      <%= adapter_config[:test_async] %>
    end

    :ok
  end<% else %>

  setup _tags do
    :ok
  end<% end %>
end
