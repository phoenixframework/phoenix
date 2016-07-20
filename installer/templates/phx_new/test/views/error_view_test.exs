defmodule <%= application_module %>.ErrorViewTest do
  use <%= application_module %>.ConnCase, async: true

  # Bring render/3 and render_to_string/3 for testing custom views
  import Phoenix.View

  <%= if html do %>test "renders 404.html" do
    assert render_to_string(<%= application_module %>.Web.ErrorView, "404.html", []) ==
           "Page not found"
  end

  test "render 500.html" do
    assert render_to_string(<%= application_module %>.Web.ErrorView, "500.html", []) ==
           "Internal server error"
  end

  test "render any other" do
    assert render_to_string(<%= application_module %>.Web.ErrorView, "505.html", []) ==
           "Internal server error"
  end<% else %>test "renders 404.json" do
    assert render(<%= application_module %>.Web.ErrorView, "404.json", []) ==
           %{errors: %{detail: "Page not found"}}
  end

  test "render 500.json" do
    assert render(<%= application_module %>.Web.ErrorView, "500.json", []) ==
           %{errors: %{detail: "Internal server error"}}
  end

  test "render any other" do
    assert render(<%= application_module %>.Web.ErrorView, "505.json", []) ==
           %{errors: %{detail: "Internal server error"}}
  end<% end %>
end
