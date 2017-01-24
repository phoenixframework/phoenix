defmodule <%= inspect module %> do
  @moduledoc """
  The boundary for the <%= human_singular %> system.
  """
  import Ecto.Query
  alias <%= inspect base_module %>.Repo

  defp apply_input_changes(_changes, changeset) do
    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end
end
