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
        file: "lib/phoenix/blog/blog.ex",
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
      File.write!("lib/phoenix/blog/blog.ex", """
      defmodule Phoenix.Blog do
      end
      """)

      schema = Schema.new("Blog.Post", "posts", [], [])
      assert %Context{pre_existing?: true} = Context.new("Blog", schema, [])
    end
  end

  test "invalid mix arguments", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/Expected the context, "blog", to be a valid module name/, fn ->
        Gen.Html.run(~w(blog Post posts title:string))
      end

      assert_raise Mix.Error, ~r/Expected the schema, "posts", to be a valid module name/, fn ->
        Gen.Html.run(~w(Post posts title:string))
      end

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Gen.Html.run(~w(Blog Blog blogs))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Html.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
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

  test "generates html context and handles existing contexts", config do
    in_tmp_project config.test, fn ->
      Gen.Html.run(~w(Blog Post posts slug:unique title:string published_at:datetime))

      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "field :published_at, :naive_datetime"
      end
      assert_file "lib/phoenix/blog/blog.ex"

      assert_file "test/blog_test.exs", fn file ->
        assert file =~ "use Phoenix.DataCase"
      end

      assert_file "test/web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostControllerTest"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")
      assert_file path, """
        defmodule Phoenix.Repo.Migrations.CreatePhoenix.Blog.Post do
          use Ecto.Migration

          def change do
            create table(:blog_posts) do
              add :slug, :string
              add :title, :string
              add :published_at, :naive_datetime

              timestamps()
            end

            create unique_index(:blog_posts, [:slug])
          end
        end
        """

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


      Gen.Html.run(~w(Blog Comment comments title:string published_at:naive_datetime edited_at:utc_datetime))
      assert_file "lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :published_at, :naive_datetime"
        assert file =~ "field :edited_at, :utc_datetime"
      end

      assert_file "test/web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.Web.CommentControllerTest"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_blog_comment.exs")
      assert_file path, """
        defmodule Phoenix.Repo.Migrations.CreatePhoenix.Blog.Comment do
          use Ecto.Migration

          def change do
            create table(:blog_comments) do
              add :title, :string
              add :published_at, :naive_datetime
              add :edited_at, :utc_datetime

              timestamps()
            end

          end
        end
        """

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
