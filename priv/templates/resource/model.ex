defmodule <%= module %> do
  use <%= base %>.Web, :model

  schema <%= inspect plural %> do
    timestamps
  end

  @doc """
  Creates a changeset based on the `model` and `params`.

  If `params` are nil, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ nil) do
    cast(model, params, ~w(), ~w())
  end
end
