defmodule <%= app_module %>.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias <%= app_module %>.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import <%= app_module %>.DataCase
    end
  end

  setup tags do
    <%= adapter_config[:test_setup] %>

    unless tags[:async] do
      <%= adapter_config[:test_async] %>
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, &replace_message_embed/2)
    end)
  end

  defp replace_message_embed({_key, value}, message) when is_tuple(value), do: message

  defp replace_message_embed({key, value}, message) do
    String.replace(message, "%{#{key}}", to_string(value))
  end
end
