defmodule Phoenix.TemplateTest do
  use ExUnit.Case, async: true

  doctest Phoenix.Template
  alias Phoenix.Template

  @templates Path.expand("../fixtures/templates", __DIR__)

  test "engines/0" do
    assert is_map Template.engines
  end

  test "template_path_to_name/2" do
    path = "/var/www/templates/admin/users/show.html.eex"
    root = "/var/www/templates"
    assert Template.template_path_to_name(path, root) ==
           "admin/users/show.html"

    path = "/var/www/templates/users/show.html.eex"
    root = "/var/www/templates"
    assert Template.template_path_to_name(path, root) ==
           "users/show.html"

    path = "/var/www/templates/home.html.eex"
    root = "/var/www/templates"
    assert Template.template_path_to_name(path, root) ==
           "home.html"

    path = "/var/www/templates/home.html.haml"
    root = "/var/www/templates"
    assert Template.template_path_to_name(path, root) ==
           "home.html"
  end

  test "find_all/1 finds all templates in the given root" do
    templates = Template.find_all @templates
    assert Path.join(@templates, "show.html.eex") in templates

    templates = Template.find_all Path.expand("../ssl", @templates)
    assert templates == []
  end

  test "hash/1 returns the hash for the given root" do
    assert is_binary Template.hash(@templates)
  end

  test "format_encoder/1 returns the formatter for a given template" do
    assert Template.format_encoder("hello.html") == Phoenix.Template.HTML
    assert Template.format_encoder("hello.js") == Phoenix.Template.HTML
    assert Template.format_encoder("hello.unknown") == nil
  end

  ## On use

  defmodule View do
    use Phoenix.Template, root: Path.join(__DIR__, "../fixtures/templates")

    def render("user.json", %{name: name}) do
      %{id: 123, name: name}
    end
  end

  test "render regular function definitions" do
    assert View.render("user.json", name: "eric") ==
           %{id: 123, name: "eric"}
  end

  test "render eex templates sanitizes against xss by default" do
    assert View.render("show.html", message: "") ==
           {:safe, [[["" | "<div>Show! "] | ""] | "</div>\n"]}

    assert View.render("show.html", message: "<script>alert('xss');</script>") ==
           {:safe, [[["" | "<div>Show! "] | "&lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;"]
                    | "</div>\n"]}
  end

  test "render eex templates allows raw data to be injected" do
    assert View.render("safe.html", message: "<script>alert('xss');</script>") ==
           {:safe, [[["" | "Raw "] | "<script>alert('xss');</script>"] | "\n"]}
  end

  test "compiles templates from path" do
    assert View.render("show.html", message: "hello!") ==
           {:safe, [[["" | "<div>Show! "] | "hello!"] | "</div>\n"]}
  end

  test "compiler adds catch-all render/2 that raises UndefinedError" do
    assert_raise Phoenix.Template.UndefinedError, ~r/Could not render "not-exists.html".*/, fn ->
      View.render("not-exists.html")
    end
  end

  test "compiler ignores missing template path" do
    defmodule OtherViews do
      use Phoenix.Template, root: Path.join(__DIR__, "not-exists")

      def template_not_found(template, _assigns) do
        "Not found: #{template}"
      end
    end

    assert OtherViews.render("foo") == "Not found: foo"
  end

  test "generates __phoenix_recompile__? function" do
    refute View.__phoenix_recompile__?
  end
end
