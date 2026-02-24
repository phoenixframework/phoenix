defmodule <%= @web_namespace %>.ErrorJSONTest do
  use <%= @web_namespace %>.ConnCase, async: true

  test "renders 404" do
    assert <%= @web_namespace %>.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert <%= @web_namespace %>.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
