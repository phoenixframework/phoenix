defmodule <%= inspect context.module %>Test do
  use <%= inspect context.base_module %>.DataCase

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  @create_attrs <%= inspect schema.params.create %>
  @update_attrs <%= inspect schema.params.update %>
  @invalid_attrs <%= inspect for {key, _} <- schema.params.create, into: %{}, do: {key, nil} %>

  def fixture(:<%= schema.singular %>, attrs \\ @create_attrs) do
    {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(attrs)
    <%= schema.singular %>
  end

  test "list_<%= schema.plural %>/1 returns all <%= schema.plural %>" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert <%= inspect context.alias %>.list_<%= schema.plural %>() == [<%= schema.singular %>]
  end

  test "get_<%= schema.singular %>! returns the <%= schema.singular %> with given id" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id) == <%= schema.singular %>
  end

  test "create_<%= schema.singular %>/1 with valid data creates a <%= schema.singular %>" do
    assert {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(@create_attrs)
    <%= for {field, value} <- schema.params.create do %>
    assert <%= schema.singular %>.<%= field %> == <%= inspect value %><% end %>
  end

  test "create_<%= schema.singular %>/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.create_<%= schema.singular %>(@invalid_attrs)
  end

  test "update_<%= schema.singular %>/2 with valid data updates the <%= schema.singular %>" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, @update_attrs)
    assert %<%= inspect schema.alias %>{} = <%= schema.singular %>
    <%= for {field, value} <- schema.params.update do %>
    assert <%= schema.singular %>.<%= field %> == <%= inspect value %><% end %>
  end

  test "update_<%= schema.singular %>/2 with invalid data returns error changeset" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, @invalid_attrs)
    assert <%= schema.singular %> == <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id)
  end

  test "delete_<%= schema.singular %>/1 deletes the <%= schema.singular %>" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert {:ok, %<%= inspect schema.alias %>{}} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>)
    assert_raise Ecto.NoResultsError, fn -> <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id) end
  end

  test "change_<%= schema.singular %>/1 returns a <%= schema.singular %> changeset" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert %Ecto.Changeset{} = <%= inspect context.alias %>.change_<%= schema.singular %>(<%= schema.singular %>)
  end
end
