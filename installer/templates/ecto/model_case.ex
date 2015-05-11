defmodule <%= application_module %>.ModelCase do
  @moduledoc """
  This module defines the test case to be used by
  model tests.

  You may define functions here to be used as helpers in
  your model tests. See `errors_on/2`'s definition as reference.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Alias the data repository and import query/model functions
      alias <%= application_module %>.Repo
      import Ecto.Model
      import Ecto.Query, only: [from: 2]
      import <%= application_module %>.ModelCase
    end
  end

  setup tags do
    unless tags[:async] do
      Ecto.Adapters.SQL.restart_test_transaction(<%= application_module %>.Repo, [])
    end

    :ok
  end

  @doc """
  Helper for returning list of errors in model when passed certain data.

  ## Examples

  Given a User model that has validation for the presence of a value for the
  `:name` field and validation that `:password` is "safe":

      iex> errors_on(%User{}, password: "password")
      [{:password, "is unsafe"}, {:name, "is blank"}]

  You would then write your assertion like:

      assert {:password, "is unsafe"} in errors_on(%User{}, password: "password")
  """
  def errors_on(model, data) do
    model.__struct__.changeset(model, data).errors
  end
end
