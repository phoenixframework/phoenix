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
    assert html == "<html>\n  <body>\n    <div>Show! hi</div>\n\n  </body>\n</html>\n"
  end

  test "render without connection renders template without layout" do
    assert MyApp.Templates.render("show.html", message: "hi", layout: false) ==
      "<div>Show! hi</div>\n"
  end

  # test "render connection renders template" do
  #   conn = conn(:get, "/")
  #   conn = MyApp.Templates.render(conn, "show", message: "hi")
  #   assert conn.resp_body == "<html>\n  <body>\n    Show! hi\n\n  </body>\n</html>\n\n"
  # end

  # test "render connection renders template without layout" do
  #   conn = conn(:get, "/")
  #   conn = MyApp.Templates.render(conn, "show", message: "hi", layout: false)
  #   assert conn.resp_body == "Show! hi\n\n"
  # end
end

