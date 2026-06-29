defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>JSON do
  alias <%= inspect schema.module %>

  @doc """
  Renders a list of <%= schema.plural %>.
  """
  def index(%{<%= schema.plural %>: <%= schema.plural %>}) do
    %{data: for(<%= schema.singular %> <- <%= schema.plural %>, do: data(<%= schema.singular %>))}
  end

  @doc """
  Renders a single <%= schema.singular %>.
  """
  def show(%{<%= schema.singular %>: <%= schema.singular %>}) do
    %{data: data(<%= schema.singular %>)}
  end

  defp data(%<%= inspect schema.alias %>{} = <%= schema.singular %>) do
    %{
<%= [{primary_key, :id} | schema.attrs] |> Enum.map(fn {k, _} -> "      #{k}: #{schema.singular}.#{k}" end) |> Enum.join(",\n")  %>
    }
  end
end
