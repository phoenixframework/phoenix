defmodule Mix.Tasks.Phoenix.RoutesTest do
  use ExUnit.Case

  defmodule TestRouter do
    use Phoenix.Router

    get "/", Phoenix.Controllers.Pages, :index, as: :page
  end

  test "format routes" do
    assert(Mix.Tasks.Phoenix.Routes.format_routes(TestRouter.__routes__) == "page  GET  /  Pages#index")
  end
end
