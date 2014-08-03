defmodule Phoenix.Template.RenderTest do
  use ExUnit.Case
  use Plug.Test
  alias Phoenix.View

  defmodule MyApp.Templates do
    use Phoenix.Template.Compiler, path: Path.join([__DIR__], "../../fixtures/templates")
    use Jazz

    def render("user.json", [name: name]) do
      JSON.encode! %{id: 123, name: name}
    end
  end

  test "render without connection renders template" do
    html = View.render(MyApp.Templates, "show.html",
      message: "hi",
      within: {MyApp.Templates, "layouts/application.html"}
    )
    assert html == "<html>\n  <body>\n    <div>Show! hi</div>\n\n  </body>\n</html>\n"
  end

  test "render a haml template with layout" do
    html = View.render(MyApp.Templates, "new.html",
      message: "hi",
      within: {MyApp.Templates, "layouts/application.html"}
    )
    assert html == "<html>\n  <body>\n    <h2>New Template</h2>\n  </body>\n</html>\n"
  end

  test "render a haml template without layout" do
    html = View.render(MyApp.Templates, "new.html", [])
    assert html == "<h2>New Template</h2>"
  end

  test "render without connection renders template without layout" do
    assert View.render(MyApp.Templates, "show.html", message: "hi") ==
      "<div>Show! hi</div>\n"
  end

  test "render can be called directly from regular functiond defs" do
    assert View.render(MyApp.Templates, "user.json", name: "eric") ==
      "{\"id\":123,\"name\":\"eric\"}"
  end
end
