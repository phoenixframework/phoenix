Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.RouterTest do
  use Phoenix.Router
  get "/", PageController, :index, as: :page
end

defmodule Mix.Tasks.Phoenix.RoutesTest do
  use ExUnit.Case, async: true

  test "format routes for specific router" do
    Mix.Tasks.Phoenix.Routes.run(["Mix.RouterTest"])
    assert_received {:mix_shell, :info, [routes]}
    assert routes =~ "page_path  GET  /  PageController :index"
  end
end
