defmodule Phoenix.ProjectTest do
  use ExUnit.Case
  alias Phoenix.Project

  test "root_module/0 returns the root module from Mix" do
    assert Project.module_root == :Phoenix
  end

  test "modules/0 returns a Stream of all modules in project" do
    assert Project.modules |> Enum.all?(&is_atom(&1))
  end
end
