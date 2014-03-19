defmodule Phoenix.ProjectTest do
  use ExUnit.Case

  test "root_module returns the root module from Mix" do
    assert Phoenix.Project.module_root == :Phoenix
  end
end
