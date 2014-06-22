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

  test "render without connection renders template without layout" do
    assert MyApp.Templates.render("show.html", message: "hi", layout: false) ==
      {:safe, "<div>Show! hi</div>\n"}
  end
end
