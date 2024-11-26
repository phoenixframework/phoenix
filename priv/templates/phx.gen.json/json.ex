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
<%= Mix.Tasks.Phx.Gen.Json.data_with_id(schema) %>
    }
  end
end
