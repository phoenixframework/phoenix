Code.require_file "../fixtures/views.exs", __DIR__

defmodule Phoenix.ViewTest do
  use ExUnit.Case, async: true

  doctest Phoenix.View
  import Phoenix.View

  ## local render

  test "converts assigns to maps even on local calls" do
    assert MyApp.UserView.render("edit.html", title: "Test") == "EDIT - Test"
  end

  ## render

  test "renders views defined on root" do
    assert render(MyApp.View, "show.html", message: "Hello world") ==
           {:safe, [[[["" | "<div>Show! "] | "Hello world"] | "</div>\n"] | "\n"]}
  end

  test "renders views keeping their template file info" do
    try do
      render(MyApp.View, "show.html", message: {:not, :a, :string})
    catch
      _, _ ->
        info = [file: 'test/fixtures/templates/show.html.eex', line: 1]
        assert {MyApp.View, :"show.html", 1, info} in System.stacktrace
    else
      _ ->
        flunk "expected rendering to raise"
    end
  end

  test "renders subviews with helpers" do
    assert render(MyApp.UserView, "index.html", title: "Hello world") ==
           {:safe, [["" | "Hello world"] | "\n"]}

    assert render(MyApp.UserView, "show.json", []) ==
           %{foo: "bar"}
  end

  test "renders views even with deeply namespace module names" do
    assert render(MyApp.Nested.UserView, "show.json", []) ==
           %{foo: "bar"}

    assert render(MyApp.Templates.UserView, "show.json", []) ==
           %{foo: "bar"}
  end

  test "renders views with layouts" do
    html = render(MyApp.View, "show.html",
      title: "Test",
      message: "Hello world",
      layout: {MyApp.LayoutView, "application.html"}
    )

    assert html ==
           {:safe, [[[[["" | "<html>\n  <title>"] | "Test"] | "</title>\n  "],
                   [[["" | "<div>Show! "] | "Hello world"] | "</div>\n"] | "\n"] | "\n</html>\n"]}
  end

  test "converts assigns to maps and removes :layout" do
    html = render_to_iodata(MyApp.UserView, "edit.html",
      title: "Test",
      layout: {MyApp.LayoutView, "application.html"}
    )

    assert html ==
           [[[[["" | "<html>\n  <title>"] | "Test"] | "</title>\n  "] | "EDIT - Test"] |
                "\n</html>\n"]
  end

  test "renders views to iodata/string using encoders" do
    assert render_to_iodata(MyApp.UserView, "index.html", title: "Hello world") ==
           [["" | "Hello world"] | "\n"]

    assert render_to_iodata(MyApp.UserView, "show.json", []) ==
           [123, [[34, ["foo"], 34], 58, [34, ["bar"], 34]], 125]

    assert render_to_string(MyApp.UserView, "index.html", title: "Hello world") ==
           "Hello world\n"

    assert render_to_string(MyApp.UserView, "show.json", []) ==
           "{\"foo\":\"bar\"}"
  end

  test "renders views with layouts to iodata/string using encoders" do
    html = render_to_iodata(MyApp.View, "show.html",
      title: "Test",
      message: "Hello world",
      layout: {MyApp.LayoutView, "application.html"}
    )

    assert html ==
           [[[[["" | "<html>\n  <title>"] | "Test"] | "</title>\n  "],
                [[["" | "<div>Show! "] | "Hello world"] | "</div>\n"] | "\n"] | "\n</html>\n"]

    html = render_to_string(MyApp.View, "show.html",
      title: "Test",
      message: "Hello world",
      layout: {MyApp.LayoutView, "application.html"}
    )

    assert html ==
           "<html>\n  <title>Test</title>\n  <div>Show! Hello world</div>\n\n\n</html>\n"
  end

  ## render_many

  test "renders many without view" do
    user = %MyApp.User{}
    assert render_many([], "show.text") == []
    assert render_many([user], "show.text") == ["show user: name"]
    assert render_many([user], "show.text", prefix: "Dr. ") == ["show user: Dr. name"]
    assert render_many([user], "show.text", %{prefix: "Dr. "}) == ["show user: Dr. name"]

    stream = Stream.concat([user], [%MyApp.Nested.User{}])
    assert render_many(stream, "show.text") ==
           ["show user: name", "show nested user: nested name"]
    assert render_many(stream, "show.text", prefix: "Dr. ") ==
           ["show user: Dr. name", "show nested user: nested name"]
  end

  test "renders many without view with custom as" do
    user = %MyApp.User{}
    assert render_many([user], "data.text", as: :data) == ["show data: name"]
  end

  test "renders many with view" do
    user = %MyApp.User{}
    assert render_many([], MyApp.UserView, "show.text") == []
    assert render_many([user], MyApp.UserView, "show.text") ==
           ["show user: name"]
    assert render_many([user], MyApp.UserView, "show.text", prefix: "Dr. ") ==
           ["show user: Dr. name"]
    assert render_many([user], MyApp.UserView, "show.text", %{prefix: "Dr. "}) ==
           ["show user: Dr. name"]

    stream = Stream.concat([user], [%MyApp.Nested.User{}])
    assert render_many(stream, MyApp.UserView, "show.text") ==
           ["show user: name", "show user: nested name"]
    assert render_many(stream, MyApp.UserView, "show.text", prefix: "Dr. ") ==
           ["show user: Dr. name", "show user: Dr. nested name"]
  end

  test "renders many with view with custom as" do
    user = %MyApp.User{}
    assert render_many([user], MyApp.UserView, "data.text", as: :data) == ["show data: name"]
  end

  ## render_one

  test "renders one without view" do
    user = %MyApp.User{}
    assert render_one(nil, "show.text") == nil
    assert render_one(user, "show.text") == "show user: name"
    assert render_one(user, "show.text", prefix: "Dr. ") == "show user: Dr. name"
    assert render_one(user, "show.text", %{prefix: "Dr. "}) == "show user: Dr. name"
  end

  test "renders one without view with custom as" do
    user = %MyApp.User{}
    assert render_one(user, "data.text", as: :data) == "show data: name"
  end

  test "renders one with view" do
    user = %MyApp.User{}
    assert render_one(nil, MyApp.UserView, "show.text") == nil
    assert render_one(user, MyApp.UserView, "show.text") ==
           "show user: name"
    assert render_one(user, MyApp.UserView, "show.text", prefix: "Dr. ") ==
           "show user: Dr. name"
    assert render_one(user, MyApp.UserView, "show.text", %{prefix: "Dr. "}) ==
           "show user: Dr. name"
  end

  test "renders one with view with custom as" do
    user = %MyApp.User{}
    assert render_one(user, MyApp.UserView, "data.text", as: :data) == "show data: name"
  end
end
