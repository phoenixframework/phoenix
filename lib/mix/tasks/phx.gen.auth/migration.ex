defmodule Mix.Tasks.Phx.Gen.Auth.Migration do
  @moduledoc false

  defstruct [:ecto_adapter, :extensions, :column_definitions]

  def build(ecto_adapter) when is_atom(ecto_adapter) do
    %__MODULE__{
      ecto_adapter: ecto_adapter,
      extensions: extensions(ecto_adapter),
      column_definitions: column_definitions(ecto_adapter)
    }
  end

  defp extensions(Ecto.Adapters.Postgres) do
    ["execute \"CREATE EXTENSION IF NOT EXISTS citext\", \"\""]
  end

  defp extensions(_), do: []

  defp column_definitions(ecto_adapter) do
    for field <- ~w(email token)a,
        into: %{},
        do: {field, column_definition(field, ecto_adapter)}
  end

  defp column_definition(:email, Ecto.Adapters.Postgres), do: "add :email, :citext, null: false"
  defp column_definition(:email, Ecto.Adapters.SQLite3), do: "add :email, :string, null: false, collate: :nocase"
  defp column_definition(:email, _), do: "add :email, :string, null: false, size: 160"

  defp column_definition(:token, Ecto.Adapters.Postgres), do: "add :token, :binary, null: false"

  defp column_definition(:token, _), do: "add :token, :binary, null: false, size: 32"
end
