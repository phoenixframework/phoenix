Code.require_file "../fixtures/views.exs", __DIR__

defmodule Phoenix.ViewTest do
  use ExUnit.Case, async: true

  doctest Phoenix.View
  alias Phoenix.View

  test "renders views defined on root" do
    assert View.render(MyApp.View, "show.html", message: "Hello world") ==
           {:safe, "<div>Show! Hello world</div>\n\n"}
  end

  test "renders views keeping their template file info" do
    try do
      View.render(MyApp.View, "show.html", message: {:not, :a, :string})
    catch
      _, _ ->
        info = [file: 'test/fixtures/templates/show.html.eex', line: 1]
        assert {MyApp.View, :"show.html", 1, info} in System.stacktrace
    else
      _ -> flunk "expected rendering to raise"
    end
  end

  test "renders subviews with helpers" do
    assert View.render(MyApp.UserView, "index.html", title: "Hello world") ==
           {:safe, "Hello world\n"}

    assert View.render(MyApp.UserView, "show.json", []) ==
           %{foo: "bar"}
  end

  test "renders views with layouts" do
    html = View.render(MyApp.View, "show.html",
      title: "Test",
      message: "Hello world",
      layout: {MyApp.LayoutView, "application.html"}
    )

    assert html ==
           {:safe, "<html>\n  <title>Test</title>\n  <div>Show! Hello world</div>\n\n\n</html>\n"}
  end

  test "renders views to iodata using encoders" do
    assert View.render_to_iodata(MyApp.UserView, "index.html", title: "Hello world") ==
           "Hello world\n"

    assert View.render_to_iodata(MyApp.UserView, "show.json", []) ==
           "{\"foo\":\"bar\"}"
  end

  test "renders views with layouts to iodata using encoders" do
    html = View.render_to_iodata(MyApp.View, "show.html",
      title: "Test",
      message: "Hello world",
      layout: {MyApp.LayoutView, "application.html"}
    )

    assert html ==
           "<html>\n  <title>Test</title>\n  <div>Show! Hello world</div>\n\n\n</html>\n"
  end

  test "converts assigns to maps and removes :layout" do
    html = View.render_to_iodata(MyApp.UserView, "edit.html",
      title: "Test",
      layout: {MyApp.LayoutView, "application.html"}
    )

    assert html ==
           "<html>\n  <title>Test</title>\n  EDIT - Test\n</html>\n"
  end
end
