defmodule <%= inspect module %> do
  @moduledoc """
  The boundary for the <%= module |> Module.split() |> List.last() %> system.
  """
  import Ecto.{Query, Changeset}
  alias <%= inspect base_module %>.Repo

  defp apply_input_changes(_changes, changeset) do
    if changeset.valid? do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end
end
