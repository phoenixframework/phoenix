<%= for {attr, {_function_name, function_def, _needs_impl?}} <- schema.fixture_unique_functions do %>  @doc """
  Generate a unique <%= schema.singular %> <%= attr %>.
  """
<%= function_def %>
<% end %>  @doc """
  Generate a <%= schema.singular %>.
  """
  def <%= schema.singular %>_fixture(attrs \\ %{}) do
    {:ok, <%= schema.singular %>} =
      attrs
      |> Enum.into(%{
<%= schema.fixture_params |> Enum.map(fn {key, code} -> "        #{key}: #{code}" end) |> Enum.join(",\n") %>
      })
      |> <%= inspect context.module %>.create_<%= schema.singular %>()

    <%= schema.singular %>
  end
