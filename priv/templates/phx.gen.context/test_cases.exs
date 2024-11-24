
  describe "<%= schema.plural %>" do
    alias <%= inspect schema.module %>

    import <%= inspect(context.module) %>Fixtures

    @invalid_attrs %{<%= schema.sample_values.invalid %>}

    test "list_<%= schema.plural %>/0 returns all <%= schema.plural %>" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
<%= virtual_clearance %>
      assert <%= inspect context.alias %>.list_<%= schema.plural %>() == [<%= schema.singular %>]
    end

    test "get_<%= schema.singular %>!/1 returns the <%= schema.singular %> with given id" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
<%= virtual_clearance %>
      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id) == <%= schema.singular %>
    end

    test "create_<%= schema.singular %>/1 with valid data creates a <%= schema.singular %>" do
<%= Mix.Phoenix.TestData.action_attrs_with_references(schema, :create) %>

      assert {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(create_attrs)
<%= Mix.Phoenix.TestData.context_values_assertions(schema, :create) %>
    end

    test "create_<%= schema.singular %>/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.create_<%= schema.singular %>(@invalid_attrs)
    end

    test "update_<%= schema.singular %>/2 with valid data updates the <%= schema.singular %>" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()

<%= Mix.Phoenix.TestData.action_attrs_with_references(schema, :update) %>

      assert {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} = <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, update_attrs)
<%= Mix.Phoenix.TestData.context_values_assertions(schema, :update) %>
    end

    test "update_<%= schema.singular %>/2 with invalid data returns error changeset" do
      <%= schema.singular %> = <%= schema.singular %>_fixture()
      assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, @invalid_attrs)
<%= virtual_clearance %>
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
