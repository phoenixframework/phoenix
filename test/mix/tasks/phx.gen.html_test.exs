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

  test "new context", config do
    in_tmp_project config.test, fn ->
      schema = Schema.new("Blog.Post", "posts", [], [])
      context = Context.new("Blog", schema, [])

      assert %Context{
        pre_existing?: false,
        alias: Blog,
        base_module: Phoenix,
        basename: "blog",
        dir: "lib/phoenix/blog",
        file: "lib/phoenix/blog.ex",
        module: Phoenix.Blog,
        web_module: Phoenix.Web,
        schema: %Mix.Phoenix.Schema{
          alias: Post,
          file: "lib/phoenix/blog/post.ex",
          human_plural: "Posts",
          human_singular: "Post",
          module: Phoenix.Blog.Post,
          plural: "posts",
          singular: "post"
        }} = context
    end
  end

  test "new existing context", config do
    in_tmp_project config.test, fn ->
      File.mkdir_p!("lib/phoenix/blog")
      File.write!("lib/phoenix/blog.ex", """
      defmodule Phoenix.Blog do
      end
      """)

      schema = Schema.new("Blog.Post", "posts", [], [])
      assert %Context{pre_existing?: true} = Context.new("Blog", schema, [])
    end
  end

  test "invalid mix arguments", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/expected the schema argument/, fn ->
        Gen.Html.run(~w(Post posts title:string))
      end

      assert_raise Mix.Error, ~r/expect a context module/, fn ->
        Gen.Html.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/expect a context module/, fn ->
        Gen.Html.run(~w(Blog Post))
      end
    end
  end

  test "name is already defined", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/already taken/, fn ->
        Gen.Html.run ~w(DupContext Post dups)
      end
    end
  end

  test "not inside single project" do
    in_tmp "not inside single project", fn ->
      assert_raise Mix.Error, ~r/can only be run inside an application directory/, fn ->
        Gen.Html.run ~w(Some Thing things)
      end
    end
  end

  test "generates html context and handles existing contexts", config do
    in_tmp_project config.test, fn ->
      Gen.Html.run(["Blog", "Post", "posts", "title:string"])

      assert_file "lib/phoenix/blog/post.ex"
      assert_file "lib/phoenix/blog.ex"

      assert_file "test/blog_test.exs", fn file ->
        assert file =~ "use Phoenix.DataCase"
      end

      assert_file "test/web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostControllerTest"
      end

      assert [_] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

      assert_file "lib/phoenix/web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Blog.get_post!"
        assert file =~ "Blog.list_posts"
        assert file =~ "Blog.create_post"
        assert file =~ "Blog.update_post"
        assert file =~ "Blog.delete_post"
        assert file =~ "Blog.change_post"
      end


      Gen.Html.run(["Blog", "Comment", "comments", "title:string"])
      assert_file "lib/phoenix/blog/comment.ex"

      assert_file "test/web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.Web.CommentControllerTest"
      end

      assert [_] = Path.wildcard("priv/repo/migrations/*_create_blog_comment.exs")

      assert_file "lib/phoenix/web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Web.CommentController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Blog.get_comment!"
        assert file =~ "Blog.list_comments"
        assert file =~ "Blog.create_comment"
        assert file =~ "Blog.update_comment"
        assert file =~ "Blog.delete_comment"
        assert file =~ "Blog.change_comment"
      end
    end
  end
end
