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
      alias <%= application_module %>.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import <%= application_module %>.ModelCase
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
  Helper for returning list of errors in a struct when given certain data.

  ## Examples

  Given a User schema that lists `:name` as a required field and validates
  `:password` to be safe, it would return:

      iex> errors_on(%User{}, %{password: "password"})
      [password: "is unsafe", name: "is blank"]

  Sometimes we need some different changeset functions e.g. registration_changeset/2 when create a User

     iex> errors_on(%User{}, %{email: "non-email"}, :registration_changeset)
     [password: "can't be blank", email: "has invalid format"]

  You could then write your assertion like:

      assert {:password, "is unsafe"} in errors_on(%User{}, %{password: "password"})

  You can also create the changeset manually and retrieve the errors
  field directly:

      iex> changeset = User.changeset(%User{}, password: "password")
      iex> {:password, "is unsafe"} in errors_on(changeset)
      true

  """
  def errors_on(struct, data, change_name \\ :changeset) do
    struct.__struct__.changeset(struct, data) |> errors_on
  end

  def errors_on(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&<%= application_module %>.ErrorHelpers.translate_error/1)
    |> Enum.flat_map(fn {key, errors} -> for msg <- errors, do: {key, msg} end)
  end
end
