defmodule Phoenix.Integration.DatabaseTagValidator do
  @moduledoc false

  # Validates that all `:database` tags in the given test files specify a valid database.
  def validate!(files) do
    for file <- files,
        {value, line} <- extract_database_tags(file) do
      if value not in valid_dbs() do
        raise(
          "#{Path.relative_to_cwd(file)}:#{line}: Invalid database tag value #{inspect(value)}. " <>
            "Expected one of #{inspect(valid_dbs())}"
        )
      end
    end

    :ok
  end

  defp extract_database_tags(file) do
    ast = file |> File.read!() |> Code.string_to_quoted!()

    {_, tags} =
      Macro.prewalk(ast, [], fn
        {:@, meta, [{kind, _, [args]}]} = node, acc
        when kind in [:tag, :moduletag, :describetag] ->
          case Keyword.fetch(normalize_tag(args), :database) do
            {:ok, value} -> {node, [{value, meta[:line]} | acc]}
            :error -> {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(tags)
  end

  defp normalize_tag(atom) when is_atom(atom), do: [{atom, true}]
  defp normalize_tag({key, value}) when is_atom(key), do: [{key, value}]
  defp normalize_tag(list) when is_list(list), do: list
  defp normalize_tag(_), do: []

  defp valid_dbs, do: [:postgresql, :mysql, :mssql, :sqlite3]
end
