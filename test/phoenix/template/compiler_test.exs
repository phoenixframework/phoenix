defmodule Phoenix.Template.CompilerTest do
  use ExUnit.Case

  defmodule MyApp.Templates do
    use Phoenix.Template.Compiler, path: Path.join([__DIR__], "../../fixtures/templates")
  end


  test "compiler precompiles all templates from path" do
    assert MyApp.Templates."show.html"(message: "hello!") == {:safe, "Show! hello!\n\n"}
  end

  test "compiler sanitizes against xss by default" do
    {:safe, html} = MyApp.Templates."show.html"(message: "<script>alert('xss');</script>")

    assert html == "Show! &lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;\n\n"
  end

  test "compiler allows {:safe, ...} to inject raw data" do
    {:safe, html} = MyApp.Templates."raw.html"(input: "<script>alert('xss');</script>")

    assert html == "Raw <script>alert('xss');</script>\n\n"
  end

  test "compiler renders application layout with nested template" do
    {:safe, html} = MyApp.Templates."show.html"(layout: "application.html", message: "hello!")

    assert html == "<html>\n  <body>\n    Show! hello!\n\n  </body>\n</html>\n\n"
  end

  test "compiler renders application layout with safe nested template" do
    {:safe, html} = MyApp.Templates."show.html"(
      layout: "application.html",
      message: "<script>alert('xss');</script>"
    )

    assert html == "<html>\n  <body>\n    Show! &lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;\n\n  </body>\n</html>\n\n"
  end

end

