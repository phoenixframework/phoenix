defmodule Phoenix.Template.RenderTest do
  use ExUnit.Case
  use Plug.Test

  defmodule MyApp.Templates do
    use Phoenix.Template.Compiler, path: Path.join([__DIR__], "../../fixtures/templates")
  end

  test "render without connection renders template" do
    html = MyApp.Templates.render("show.html",
      message: "hi",
      within: {MyApp.Templates, "layouts/application.html"}
    )
    assert html == {:safe, "<html>\n  <body>\n    <div>Show! hi</div>\n\n  </body>\n</html>\n"}
  end

  test "render a haml template with layout" do
    html = MyApp.Templates.render("new.html",
      message: "hi",
      within: {MyApp.Templates, "layouts/application.html"}
    )
    assert html == {:safe, "<html>\n  <body>\n    <h2>New Template</h2>\n  </body>\n</html>\n"}
  end

  test "render a haml template without layout" do
    html = MyApp.Templates.render("new.html", layout: false)
    assert html == {:safe, "<h2>New Template</h2>"}
  end

  test "render without connection renders template without layout" do
    assert MyApp.Templates.render("show.html", message: "hi", layout: false) ==
      {:safe, "<div>Show! hi</div>\n"}
  end
end
