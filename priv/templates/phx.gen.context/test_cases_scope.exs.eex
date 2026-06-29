
  describe "<%= schema.plural %>" do
    alias <%= inspect schema.module %>

    import <%= inspect scope.test_data_fixture %>, only: [<%= scope.name %>_scope_fixture: 0]
    import <%= inspect context.module %>Fixtures

    @invalid_attrs <%= Mix.Phoenix.to_text for {key, _} <- schema.params.create, into: %{}, do: {key, nil} %>

    test "list_<%= schema.plural %>/1 returns all scoped <%= schema.plural %>" do
      scope = <%= scope.name %>_scope_fixture()
      other_scope = <%= scope.name %>_scope_fixture()
      <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
      other_<%= schema.singular %> = <%= schema.singular %>_fixture(other_scope)
      assert <%= inspect context.alias %>.list_<%= schema.plural %>(scope) == [<%= schema.singular %>]
      assert <%= inspect context.alias %>.list_<%= schema.plural %>(other_scope) == [other_<%= schema.singular %>]
    end

    test "get_<%= schema.singular %>!/2 returns the <%= schema.singular %> with given id" do
      scope = <%= scope.name %>_scope_fixture()
      <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
      other_scope = <%= scope.name %>_scope_fixture()
      assert <%= inspect context.alias %>.get_<%= schema.singular %>!(scope, <%= schema.singular %>.<%= schema.opts[:primary_key] || :id %>) == <%= schema.singular %>
      assert_raise Ecto.NoResultsError, fn -> <%= inspect context.alias %>.get_<%= schema.singular %>!(other_scope, <%= schema.singular %>.<%= schema.opts[:primary_key] || :id %>) end
    end

    test "create_<%= schema.singular %>/2 with valid data creates a <%= schema.singular %>" do
      valid_attrs = <%= Mix.Phoenix.to_text schema.params.create %>
      scope = <%= scope.name %>_scope_fixture()

      assert {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(scope, valid_attrs)<%= for {field, value} <- schema.params.create do %>
      assert <%= schema.singular %>.<%= field %> == <%= Mix.Phoenix.Schema.value(schema, field, value) %><% end %>
      assert <%= schema.singular %>.<%= scope.schema_key %> == scope.<%= scope.access_path |> Enum.join(".") %>
    end

    test "create_<%= schema.singular %>/2 with invalid data returns error changeset" do
      scope = <%= scope.name %>_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.create_<%= schema.singular %>(scope, @invalid_attrs)
    end

    test "update_<%= schema.singular %>/3 with valid data updates the <%= schema.singular %>" do
      scope = <%= scope.name %>_scope_fixture()
      <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
      update_attrs = <%= Mix.Phoenix.to_text schema.params.update%>

      assert {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} = <%= inspect context.alias %>.update_<%= schema.singular %>(scope, <%= schema.singular %>, update_attrs)<%= for {field, value} <- schema.params.update do %>
      assert <%= schema.singular %>.<%= field %> == <%= Mix.Phoenix.Schema.value(schema, field, value) %><% end %>
    end

    test "update_<%= schema.singular %>/3 with invalid scope raises" do
      scope = <%= scope.name %>_scope_fixture()
      other_scope = <%= scope.name %>_scope_fixture()
      <%= schema.singular %> = <%= schema.singular %>_fixture(scope)

      assert_raise MatchError, fn ->
        <%= inspect context.alias %>.update_<%= schema.singular %>(other_scope, <%= schema.singular %>, %{})
      end
    end

    test "update_<%= schema.singular %>/3 with invalid data returns error changeset" do
      scope = <%= scope.name %>_scope_fixture()
      <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.update_<%= schema.singular %>(scope, <%= schema.singular %>, @invalid_attrs)
      assert <%= schema.singular %> == <%= inspect context.alias %>.get_<%= schema.singular %>!(scope, <%= schema.singular %>.<%= schema.opts[:primary_key] || :id %>)
    end

    test "delete_<%= schema.singular %>/2 deletes the <%= schema.singular %>" do
      scope = <%= scope.name %>_scope_fixture()
      <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
      assert {:ok, %<%= inspect schema.alias %>{}} = <%= inspect context.alias %>.delete_<%= schema.singular %>(scope, <%= schema.singular %>)
      assert_raise Ecto.NoResultsError, fn -> <%= inspect context.alias %>.get_<%= schema.singular %>!(scope, <%= schema.singular %>.<%= schema.opts[:primary_key] || :id %>) end
    end

    test "delete_<%= schema.singular %>/2 with invalid scope raises" do
      scope = <%= scope.name %>_scope_fixture()
      other_scope = <%= scope.name %>_scope_fixture()
      <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
      assert_raise MatchError, fn -> <%= inspect context.alias %>.delete_<%= schema.singular %>(other_scope, <%= schema.singular %>) end
    end

    test "change_<%= schema.singular %>/2 returns a <%= schema.singular %> changeset" do
      scope = <%= scope.name %>_scope_fixture()
      <%= schema.singular %> = <%= schema.singular %>_fixture(scope)
      assert %Ecto.Changeset{} = <%= inspect context.alias %>.change_<%= schema.singular %>(scope, <%= schema.singular %>)
    end
  end
