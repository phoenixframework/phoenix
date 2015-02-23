defmodule Mix.Tasks.Phoenix.RoutesTest do
  use ExUnit.Case, async: true

  test "format routes for specific router" do
    Mix.Tasks.Phoenix.Routes.run(["Mix.RouterTest"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /  PageController.index/2"
  end
end
