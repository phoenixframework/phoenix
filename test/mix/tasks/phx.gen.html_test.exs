Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.HtmlTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
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

  test "generates html resource and handles existing contexts", config do
    in_tmp_project config.test, fn ->
      Gen.Html.run(~w(Blog Post posts title slug:unique votes:integer cost:decimal
                      tags:array:text popular:boolean drafted_at:datetime
                      published_at:utc_datetime deleted_at:naive_datetime
                      secret:uuid announcement_date:date alarm:time
                      user_id:references:users))

      assert_file "lib/phoenix/blog/post.ex"
      assert_file "lib/phoenix/blog/blog.ex"
      assert_file "test/blog_test.exs", fn file ->
        assert file =~ "alarm: ~T[14:00:00]"
        assert file =~ "announcement_date: ~D[2010-04-17]"
        assert file =~ "deleted_at: ~N[2010-04-17 14:00:00.000000]"
        assert file =~ "published_at: %DateTime{"

        assert file =~ "assert post.announcement_date == ~D[2011-05-18]"
        assert file =~ "assert post.deleted_at == ~N[2011-05-18 15:01:01.000000]"
        assert file =~ "assert post.published_at == %DateTime{"
      end

      assert_file "test/web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostControllerTest"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:blog_posts)"
        assert file =~ "add :title, :string"
        assert file =~ "create unique_index(:blog_posts, [:slug])"
      end

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

      assert_file "lib/phoenix/web/templates/post/form.html.eex", fn file ->
        assert file =~ ~s(<%= text_input f, :title, class: "form-control" %>)
        assert file =~ ~s(<%= number_input f, :votes, class: "form-control" %>)
        assert file =~ ~s(<%= number_input f, :cost, step: "any", class: "form-control" %>)
        assert file =~ ~s(<%= checkbox f, :popular, class: "checkbox" %>)
        assert file =~ ~s(<%= datetime_select f, :drafted_at, class: "form-control" %>)
        assert file =~ ~s(<%= datetime_select f, :published_at, class: "form-control" %>)
        assert file =~ ~s(<%= datetime_select f, :deleted_at, class: "form-control" %>)
        assert file =~ ~s(<%= date_select f, :announcement_date, class: "form-control" %>)
        assert file =~ ~s(<%= time_select f, :alarm, class: "form-control" %>)
        assert file =~ ~s(<%= text_input f, :secret, class: "form-control" %>)

        assert file =~ ~s(<%= label f, :title, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :votes, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :cost, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :popular, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :drafted_at, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :published_at, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :deleted_at, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :announcement_date, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :alarm, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :secret, class: "control-label" %>)

        refute file =~ ":tags"
        refute file =~ ~s(<%= label f, :user_id)
        refute file =~ ~s(<%= number_input f, :user_id)
      end

      Gen.Html.run(~w(Blog Comment comments title:string))
      assert_file "lib/phoenix/blog/comment.ex"

      assert_file "test/web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.Web.CommentControllerTest"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_blog_comment.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:blog_comments)"
        assert file =~ "add :title, :string"
      end

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
