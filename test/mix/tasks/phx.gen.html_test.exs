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
                      weight:float user_id:references:users))

      assert_file "lib/phoenix/blog/post.ex"
      assert_file "lib/phoenix/blog/blog.ex"
      assert_file "test/phoenix/blog/blog_test.exs", fn file ->
        assert file =~ "alarm: ~T[15:01:01.000000]"
        assert file =~ "announcement_date: ~D[2010-04-17]"
        assert file =~ "deleted_at: ~N[2010-04-17 14:00:00.000000]"
        assert file =~ "cost: \"120.5\""
        assert file =~ "published_at: \"2010-04-17 14:00:00.000000Z\""
        assert file =~ "weight: 120.5"

        assert file =~ "assert post.announcement_date == ~D[2011-05-18]"
        assert file =~ "assert post.deleted_at == ~N[2011-05-18 15:01:01.000000]"
        assert file =~ "assert post.published_at == DateTime.from_naive!(~N[2011-05-18 15:01:01.000000Z], \"Etc/UTC\")"
        assert file =~ "assert post.alarm == ~T[15:01:01.000000]"
        assert file =~ "assert post.cost == Decimal.new(\"120.5\")"
        assert file =~ "assert post.weight == 120.5"
      end

      assert_file "test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostControllerTest"
        assert file =~ " post_path(conn"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:posts)"
        assert file =~ "add :title, :string"
        assert file =~ "create unique_index(:posts, [:slug])"
      end

      assert_file "lib/phoenix_web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ "Blog.get_post!"
        assert file =~ "Blog.list_posts"
        assert file =~ "Blog.create_post"
        assert file =~ "Blog.update_post"
        assert file =~ "Blog.delete_post"
        assert file =~ "Blog.change_post"
        assert file =~ "redirect(to: post_path(conn"
      end

      assert_file "lib/phoenix_web/views/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostView"
      end

      assert_file "lib/phoenix_web/templates/post/edit.html.eex", fn file ->
        assert file =~ " post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/post/index.html.eex", fn file ->
        assert file =~ " post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/post/new.html.eex", fn file ->
        assert file =~ " post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/post/show.html.eex", fn file ->
        assert file =~ " post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/post/form.html.eex", fn file ->
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

      send self(), {:mix_shell_input, :yes?, true}
      Gen.Html.run(~w(Blog Comment comments title:string))
      assert_received {:mix_shell, :info, ["You are generating into an existing context" <> _]}

      assert_file "lib/phoenix/blog/comment.ex"

      assert_file "test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:comments)"
        assert file =~ "add :title, :string"
      end

      assert_file "lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ "Blog.get_comment!"
        assert file =~ "Blog.list_comments"
        assert file =~ "Blog.create_comment"
        assert file =~ "Blog.update_comment"
        assert file =~ "Blog.delete_comment"
        assert file =~ "Blog.change_comment"
        assert file =~ "redirect(to: comment_path(conn"
      end

      assert_receive {:mix_shell, :info, ["""

      Add the resource to your browser scope in lib/phoenix_web/router.ex:

          resources "/posts", PostController
      """]}
    end
  end

  test "with --web namespace generates namedspaced web modules and directories", config do
    in_tmp_project config.test, fn ->
      Gen.Html.run(~w(Blog Post posts title:string --web Blog))

      assert_file "test/phoenix_web/controllers/blog/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostControllerTest"
        assert file =~ " blog_post_path(conn"
      end

      assert_file "lib/phoenix_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ "redirect(to: blog_post_path(conn"
      end

      assert_file "lib/phoenix_web/templates/blog/post/form.html.eex"

      assert_file "lib/phoenix_web/templates/blog/post/edit.html.eex", fn file ->
        assert file =~ " blog_post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/blog/post/index.html.eex", fn file ->
        assert file =~ " blog_post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/blog/post/new.html.eex", fn file ->
        assert file =~ " blog_post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/blog/post/show.html.eex", fn file ->
        assert file =~ " blog_post_path(@conn"
      end

      assert_file "lib/phoenix_web/views/blog/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostView"
      end

      assert_receive {:mix_shell, :info, ["""

      Add the resource to your Blog :browser scope in lib/phoenix_web/router.ex:

          scope "/blog", PhoenixWeb.Blog, as: :blog do
            pipe_through :browser
            ...
            resources "/posts", PostController
          end
      """]}
    end
  end

  test "with --no-context skips context and schema file generation", config do
    in_tmp_project config.test, fn ->
      Gen.Html.run(~w(Blog Comment comments title:string --no-context))

      refute_file "lib/phoenix/blog/blog.ex"
      refute_file "lib/phoenix/blog/comment.ex"
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file "test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end

      assert_file "lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
      end

      assert_file "lib/phoenix_web/templates/comment/form.html.eex"
      assert_file "lib/phoenix_web/views/comment_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentView"
      end
    end
  end

  test "with --no-schema skips schema file generation", config do
    in_tmp_project config.test, fn ->
      Gen.Html.run(~w(Blog Comment comments title:string --no-schema))

      assert_file "lib/phoenix/blog/blog.ex"
      refute_file "lib/phoenix/blog/comment.ex"
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file "test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end

      assert_file "lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
      end

      assert_file "lib/phoenix_web/templates/comment/form.html.eex"
      assert_file "lib/phoenix_web/views/comment_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentView"
      end
    end
  end

  describe "inside umbrella" do
    test "without context_app generators config uses web dir", config do
      in_tmp_umbrella_project config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: nil)
        Gen.Html.run(~w(Accounts User users name:string))

        assert_file "lib/phoenix/accounts/accounts.ex"
        assert_file "lib/phoenix/accounts/user.ex"

        assert_file "lib/phoenix_web/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserController"
          assert file =~ "use PhoenixWeb, :controller"
        end

        assert_file "lib/phoenix_web/templates/user/form.html.eex"
        assert_file "lib/phoenix_web/views/user_view.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserView"
        end

        assert_file "test/phoenix_web/controllers/user_controller_test.exs", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserControllerTest"
        end
      end
    end

    test "raises with false context_app", config do
      in_tmp_umbrella_project config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: false)
        assert_raise Mix.Error, ~r/no context_app configured/, fn ->
          Gen.Html.run(~w(Accounts User users name:string))
        end
      end
    end

    test "with context_app generators config does not use web dir", config do
      in_tmp_umbrella_project config.test, fn ->
        File.mkdir!("another_app")
        Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})

        Gen.Html.run(~w(Accounts User users name:string))

        assert_file "another_app/lib/another_app/accounts/accounts.ex"
        assert_file "another_app/lib/another_app/accounts/user.ex"

        assert_file "lib/phoenix/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserController"
          assert file =~ "use PhoenixWeb, :controller"
        end

        assert_file "lib/phoenix/templates/user/form.html.eex"
        assert_file "lib/phoenix/views/user_view.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserView"
        end

        assert_file "test/phoenix/controllers/user_controller_test.exs", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserControllerTest"
        end
      end
    end
  end
end
