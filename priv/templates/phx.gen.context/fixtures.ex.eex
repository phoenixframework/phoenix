<%= for {attr, {_function_name, function_def, _needs_impl?}} <- schema.fixture_unique_functions do %>  @doc """
  Generate a unique <%= schema.singular %> <%= attr %>.
  """
<%= function_def %>
<% end %>  @doc """
  Generate a <%= schema.singular %>.
  """
  def <%= schema.singular %>_fixture(<%= if scope do %>scope, <% end %>attrs \\ %{}) do<%= if scope do %>
    attrs =
      Enum.into(attrs, %{
<%= schema.fixture_params |> Enum.map(fn {key, code} -> "        #{key}: #{code}" end) |> Enum.join(",\n") %>
      })

    {:ok, <%= schema.singular %>} = <%= inspect context.module %>.create_<%= schema.singular %>(scope, attrs)<% else %>
    {:ok, <%= schema.singular %>} =
      attrs
      |> Enum.into(%{
<%= schema.fixture_params |> Enum.map(fn {key, code} -> "        #{key}: #{code}" end) |> Enum.join(",\n") %>
      })
      |> <%= inspect context.module %>.create_<%= schema.singular %>()
<% end %>
    <%= schema.singular %>
  end
