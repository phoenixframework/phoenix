defmodule <%= inspect context.module %>Test do
  use <%= inspect context.base_module %>.DataCase

  alias <%= inspect context.module %>
  alias <%= inspect schema.module %>

  @valid_attrs <%= inspect schema.params.default %>
  @invalid_attrs <%= inspect for {key, _} <- schema.params.default, into: %{}, do: {key, nil} %>

  def fixture(:<%= schema.singular %>, attrs \\ @valid_attrs) do
    {:ok, <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(attrs)
    <%= schema.singular %>
  end

  test "list_<%= schema.plural %>/1 returns all <%= schema.plural %>" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert [^<%= schema.singular %>] = <%= inspect context.alias %>.list_<%= schema.plural %>()
  end

  test "get_<%= schema.singular %>! returns the <%= schema.singular %> with given id" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert ^<%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id)
  end

  test "get_<%= schema.singular %>! with no existing <%= schema.singular %> raises" do
    assert_raise Ecto.NoResultsError, fn -> <%= inspect context.alias %>.get_<%= schema.singular %>!(-1) end
  end

  test "create_<%= schema.singular %>/1 with valid data creates a <%= schema.singular %>" do
    assert {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} = <%= inspect context.alias %>.create_<%= schema.singular %>(@valid_attrs)
    <%= for {field, value} <- schema.params.default do %>
    assert <%= schema.singular %>.<%= field %> == <%= inspect value %><% end %>
  end

  test "create_<%= schema.singular %>/1 with invalid data returns error changeset" do
    assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.create_<%= schema.singular %>(@invalid_attrs)
  end

  test "update_<%= schema.singular %>/2 with valid data updates the <%= schema.singular %>" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert {:ok, %<%= inspect schema.alias %>{} = <%= schema.singular %>} = <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, %{<%= schema.params.default_key %>: <%= inspect schema.params.update[schema.params.default_key] %>})
    assert <%= schema.singular %>.<%= schema.params.default_key %> == <%= inspect schema.params.update[schema.params.default_key] %>
  end

  test "update_<%= schema.singular %>/2 with invalid data returns error changeset" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert {:error, %Ecto.Changeset{}} = <%= inspect context.alias %>.update_<%= schema.singular %>(<%= schema.singular %>, @invalid_attrs)
    assert <%= schema.singular %> == <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id)
  end

  test "delete_<%= schema.singular %>/1 deletes the <%= schema.singular %>" do
    <%= schema.singular %> = fixture(:<%= schema.singular %>)
    assert ^<%= schema.singular %> = <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id)
    assert {:ok, %<%= inspect schema.alias %>{}} = <%= inspect context.alias %>.delete_<%= schema.singular %>(<%= schema.singular %>)
    assert_raise Ecto.NoResultsError, fn -> <%= inspect context.alias %>.get_<%= schema.singular %>!(<%= schema.singular %>.id) end
  end
end
