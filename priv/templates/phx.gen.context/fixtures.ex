
  def <%= schema.singular %>_fixture(attrs \\ %{}) do
    {:ok, <%= schema.singular %>} =
      attrs
      |> Enum.into(%{
<%= schema.params.create |> Enum.map(fn {key, val} -> "        #{key}: #{inspect(val)}" end) |> Enum.join(",\n") %>
      })
      |> <%= inspect context.module %>.create_<%= schema.singular %>()

    <%= schema.singular %>
  end
