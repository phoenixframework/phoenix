<%= for {attr_name, {_, function_def, _}} <- fixture.unique_functions do %>  @doc """
  Generate a unique <%= schema.singular %> <%= attr_name %>.
  """
<%= function_def %>
<% end %>  @doc """
  Generate a <%= schema.singular %>.
  """
  def <%= schema.singular %>_fixture(attrs \\ %{}) do
<%= schema.sample_values.references_assigns |> Mix.Phoenix.indent_text(spaces: 4, bottom: 2) %>    {:ok, <%= schema.singular %>} =
      attrs
      |> Enum.into(%{<%= fixture.attrs %>
      })
      |> <%= inspect(context.module) %>.create_<%= schema.singular %>()

    <%= schema.singular %>
  end
