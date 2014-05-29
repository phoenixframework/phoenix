defmodule Phoenix.Template.CompilerTest do
  use ExUnit.Case

  defmodule MyApp.Views do
    use Phoenix.Template.Compiler, path: Path.join([__DIR__], "../../fixtures/templates")
  end


  test "compiler precompiles all templates from path" do
    assert MyApp.Views.render("show.html", message: "hello!") == "<div>Show! hello!</div>\n\n"
  end

  test "compiler sanitizes against xss by default" do
    html = MyApp.Views.render("show.html", message: "<script>alert('xss');</script>")

    assert html == "<div>Show! &lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;</div>\n\n"
  end

  test "compiler allows {:safe, ...} to inject raw data" do
    html = MyApp.Views.render("raw.html", input: "<script>alert('xss');</script>")

    assert html == "Raw <script>alert('xss');</script>\n\n"
  end

  test "compiler renders application layout with nested template" do
    html = MyApp.Views.render("show.html", layout: "application.html", message: "hello!")

    assert html == "<html>\n  <body>\n    <div>Show! hello!</div>\n\n  </body>\n</html>\n\n"
  end

  test "compiler renders application layout with safe nested template" do
    html = MyApp.Views.render("show.html",
      layout: "application.html",
      message: "<script>alert('xss');</script>"
    )

    assert html == "<html>\n  <body>\n    <div>Show! &lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;</div>\n\n  </body>\n</html>\n\n"
  end

  test "compiler adds cach-all render/2 that raises UndefinedError" do
    assert_raise Phoenix.Template.UndefinedError, fn ->
      MyApp.Views.render("not-exists.html", [])
    end
  end

  test "missing template path raises UndefinedError" do
    assert_raise Phoenix.Template.UndefinedError, fn ->
      defmodule MyApp2.Views do
        use Phoenix.Template.Compiler, path: Path.join([__DIR__], "not-exists")
      end
    end
  end
end

