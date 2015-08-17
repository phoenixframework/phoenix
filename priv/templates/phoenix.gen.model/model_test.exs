defmodule <%= module %>Test do
  use <%= base %>.ModelCase

  alias <%= module %>

  @valid_params <%= inspect params %>
  @invalid_params %{}

  test "changeset with valid attributes" do
    changeset = <%= alias %>.changeset(%<%= alias %>{}, @valid_params)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = <%= alias %>.changeset(%<%= alias %>{}, @invalid_params)
    refute changeset.valid?
  end
end
