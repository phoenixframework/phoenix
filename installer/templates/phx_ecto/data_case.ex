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
  A helper that converts the changeset error messages
  for a given field into a list of strings for assertion:

      changeset = Blog.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset, :password)

  """
  def errors_on(changeset, field) do
    for {message, opts} <- Keyword.get_values(changeset.errors, field) do
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end
  end
end
