defmodule Mix.Tasks.Phoenix.RoutesTest do
  use ExUnit.Case

  test "formats routes as nice string" do

    assert(Mix.Tasks.Phoenix.Routes.format_routes(routes) == "   GET  /                             Elixir.Trash.Main#index")
  end

end
