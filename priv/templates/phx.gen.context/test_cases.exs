
  describe "<%= schema.plural %>" do
    alias <%= inspect schema.module %>

    @valid_attrs <%= inspect schema.params.create %>
    @update_attrs <%= inspect schema.params.update %>
    @invalid_attrs <%= inspect for {key, _} <- schema.params.create, into: %{}, do: {key, nil} %>

    def <%= schema.singular %>_fixture(attrs \\ %{}) do
      {:ok, <%= schema.singular %>} =
        attrs
        |> Enum.into(@valid_attrs)
        |> <%= inspect context.alias %>.create_<%= schema.singular %>()

      <%= schema.singular %>
    end

    test "list_<%= schema.plural %>/0 returns all <%= schema.plural %>" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert <%= inspect context.alias %>.list_<%= schema.plural %>() == [<%= schema.singular %>]
    end

    test "get_<%= schema.singular %>!/1 returns the <%= schema.singular %> with given id" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id) == <%= schema.singular %>
    end

    test "create_<%= schema.singular %>/1 with valid data creates a <%= schema.singular %>" do
      assert {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(@valid_attrs)<%= for {field, value} <- schema.params.create do %>
      assert <%= schema.singular %>.<%= field %> == <%= Mix.Phoenix.Schema.value(schema, field, value) %><% end %>
    end

    test "create_<%= schema.singular %>/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.create_<%= schema.singular %>(@invalid_attrs)
    end

    test "update_<%= schema.singular %>/2 with valid data updates the <%= schema.singular %>" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, @update_attrs)
      assert %<%= inspect schema.alias %>{} = <%= schema.singular %><%= for {field, value} <- schema.params.update do %>
      assert <%= schema.singular %>.<%= field %> == <%= Mix.Phoenix.Schema.value(schema, field, value) %><% end %>
    end

    test "update_<%= schema.singular %>/2 with invalid data returns error changeset" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, @invalid_attrs)
      assert <%= schema.singular %> == <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id)
    end

    test "delete_<%= schema.singular %>/1 deletes the <%= schema.singular %>" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert {:ok, %<%= inspect schema.alias %>{}} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>)
      assert_raise Ecto.NoResultsError, fn -> <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id) end
    end

    test "change_<%= schema.singular %>/1 returns a <%= schema.singular %> changeset" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert %Ecto.Changeset{} = <%= inspect context.alias %>.change_<%= schema.singular %>(<%= schema.singular %>)
    end
  end
