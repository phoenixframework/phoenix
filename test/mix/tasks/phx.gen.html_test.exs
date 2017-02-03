Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.DupContext do
end

defmodule Mix.Tasks.Phx.Gen.HtmlTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen
  alias Mix.Phoenix.{Context, Schema}

  setup do
    Mix.Task.clear()
    :ok
  end

  test "new context" do
    in_tmp "new context", fn ->
      schema = Schema.new("Blog.Post", "posts", [], [])
      context = Context.new("Blog", schema, [])

      assert %Context{
        pre_existing?: false,
        alias: Blog,
        base_module: Phoenix,
        basename: "blog",
        dir: "lib/blog",
        file: "lib/blog.ex",
        module: Phoenix.Blog,
        web_module: Phoenix.Web,
        schema: %Mix.Phoenix.Schema{
          alias: Post,
          file: "lib/blog/post.ex",
          human_plural: "Posts",
          human_singular: "Post",
          module: Phoenix.Blog.Post,
          plural: "posts",
          singular: "post"
        }} = context
    end
  end

  test "new existing context" do
    in_tmp "new existing context", fn ->
      File.mkdir_p!("lib/blog")
      File.write!("lib/blog.ex", """
      defmodule Phoenix.Blog do
      end
      """)

      schema = Schema.new("Blog.Post", "posts", [], [])
      assert %Context{pre_existing?: true} = Context.new("Blog", schema, [])
    end
  end

  test "invalid mix arguments" do
    in_tmp "invalid mix arguments", fn ->
      assert_raise Mix.Error, ~r/expects a context module/, fn ->
        Gen.Html.run(~w(Post posts title:string))
      end

      assert_raise Mix.Error, ~r/expects a context module/, fn ->
        Gen.Html.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/expects a context module/, fn ->
        Gen.Html.run(~w(Blog Post))
      end
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, ~r/already taken/, fn ->
      Gen.Html.run ~w(DupContext Post dups)
    end
  end

  test "generates html context" do
    in_tmp "generates html context", fn ->
      Gen.Html.run(["Blog", "Post", "posts", "title:string"])

      assert_file "lib/blog/post.ex"
      assert_file "lib/blog.ex"

      assert_file "test/blog_test.exs", fn file ->
        assert file =~ "use Phoenix.DataCase"
      end

      assert_file "test/web/controllers/post_controller_test.exs"

      assert [_] = Path.wildcard("priv/repo/migrations/*_create_post.exs")

      assert_file "lib/web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Blog.get_post!"
      end
    end
  end
end
