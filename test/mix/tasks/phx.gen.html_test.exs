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

      assert_raise Mix.Error, ~r/Enum type requires at least two values/, fn ->
        Gen.Html.run(~w(Blog Post posts status:enum))
      end

      assert_raise Mix.Error, ~r/Enum type requires at least two values/, fn ->
        Gen.Html.run(~w(Blog Post posts status:enum:new))
      end
    end
  end

  test "generates html resource and handles existing contexts", config do
    one_day_in_seconds = 24 * 3600
    naive_datetime = %{NaiveDateTime.utc_now() | second: 0, microsecond: {0, 6}}
    datetime = %{DateTime.utc_now() | second: 0, microsecond: {0, 6}}

    in_tmp_project config.test, fn ->
      Gen.Html.run(~w(Blog Post posts title slug:unique votes:integer cost:decimal
                      tags:array:text popular:boolean drafted_at:datetime
                      status:enum:unpublished:published:deleted
                      published_at:utc_datetime
                      published_at_usec:utc_datetime_usec
                      deleted_at:naive_datetime
                      deleted_at_usec:naive_datetime_usec
                      alarm:time
                      alarm_usec:time_usec
                      secret:uuid:redact announcement_date:date alarm:time
                      weight:float user_id:references:users))

      assert_file "lib/phoenix/blog/post.ex"
      assert_file "lib/phoenix/blog.ex"
      assert_file "test/phoenix/blog_test.exs", fn file ->
        assert file =~ "alarm: ~T[15:01:01]"
        assert file =~ "alarm_usec: ~T[15:01:01.000000]"
        assert file =~ "announcement_date: #{Date.utc_today() |> Date.add(-1) |> inspect()}"
        assert file =~ "deleted_at: #{naive_datetime |> NaiveDateTime.add(-one_day_in_seconds) |> NaiveDateTime.truncate(:second) |> inspect()}"
        assert file =~ "deleted_at_usec: #{naive_datetime |> NaiveDateTime.add(-one_day_in_seconds) |> inspect()}"
        assert file =~ "cost: \"120.5\""
        assert file =~ "published_at: #{datetime |> DateTime.add(-one_day_in_seconds) |> DateTime.truncate(:second) |> inspect()}"
        assert file =~ "published_at_usec: #{datetime |> DateTime.add(-one_day_in_seconds) |> inspect()}"
        assert file =~ "weight: 120.5"
        assert file =~ "status: :published"

        assert file =~ "assert post.announcement_date == #{inspect(Date.utc_today())}"
        assert file =~ "assert post.deleted_at == #{naive_datetime |> NaiveDateTime.truncate(:second) |> inspect()}"
        assert file =~ "assert post.deleted_at_usec == #{inspect(naive_datetime)}"
        assert file =~ "assert post.published_at == #{datetime |> DateTime.truncate(:second) |> inspect()}"
        assert file =~ "assert post.published_at_usec == #{inspect(datetime)}"
        assert file =~ "assert post.alarm == ~T[15:01:01]"
        assert file =~ "assert post.alarm_usec == ~T[15:01:01.000000]"
        assert file =~ "assert post.cost == Decimal.new(\"120.5\")"
        assert file =~ "assert post.weight == 120.5"
        assert file =~ "assert post.status == :published"
      end

      assert_file "test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostControllerTest"
        assert file =~ " Routes.post_path(conn"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:posts)"
        assert file =~ "add :title, :string"
        assert file =~ "add :status, :string"
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
        assert file =~ "redirect(to: Routes.post_path(conn"
      end

      assert_file "lib/phoenix_web/views/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostView"
      end

      assert_file "lib/phoenix_web/templates/post/edit.html.eex", fn file ->
        assert file =~ " Routes.post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/post/index.html.eex", fn file ->
        assert file =~ " Routes.post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/post/new.html.eex", fn file ->
        assert file =~ " Routes.post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/post/show.html.eex", fn file ->
        assert file =~ " Routes.post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/post/form.html.eex", fn file ->
        assert file =~ ~s(<%= text_input f, :title %>)
        assert file =~ ~s(<%= number_input f, :votes %>)
        assert file =~ ~s(<%= number_input f, :cost, step: "any" %>)
        assert file =~ ~s(<%= multiple_select f, :tags, ["Option 1": "option1", "Option 2": "option2"] %>)
        assert file =~ ~s(<%= checkbox f, :popular %>)
        assert file =~ ~s(<%= datetime_select f, :drafted_at %>)
        assert file =~ ~s(<%= datetime_select f, :published_at %>)
        assert file =~ ~s(<%= datetime_select f, :deleted_at %>)
        assert file =~ ~s(<%= date_select f, :announcement_date %>)
        assert file =~ ~s(<%= time_select f, :alarm %>)
        assert file =~ ~s(<%= text_input f, :secret %>)
        assert file =~ ~s|<%= select f, :status, Ecto.Enum.values(Phoenix.Blog.Post, :status), prompt: "Choose a value" %>|

        assert file =~ ~s(<%= label f, :title %>)
        assert file =~ ~s(<%= label f, :votes %>)
        assert file =~ ~s(<%= label f, :cost %>)
        assert file =~ ~s(<%= label f, :tags %>)
        assert file =~ ~s(<%= label f, :popular %>)
        assert file =~ ~s(<%= label f, :drafted_at %>)
        assert file =~ ~s(<%= label f, :published_at %>)
        assert file =~ ~s(<%= label f, :deleted_at %>)
        assert file =~ ~s(<%= label f, :announcement_date %>)
        assert file =~ ~s(<%= label f, :alarm %>)
        assert file =~ ~s(<%= label f, :secret %>)
        assert file =~ ~s(<%= label f, :status %>)

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
        assert file =~ "redirect(to: Routes.comment_path(conn"
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
        assert file =~ " Routes.blog_post_path(conn"
      end

      assert_file "lib/phoenix_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ "redirect(to: Routes.blog_post_path(conn"
      end

      assert_file "lib/phoenix_web/templates/blog/post/form.html.eex"

      assert_file "lib/phoenix_web/templates/blog/post/edit.html.eex", fn file ->
        assert file =~ " Routes.blog_post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/blog/post/index.html.eex", fn file ->
        assert file =~ " Routes.blog_post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/blog/post/new.html.eex", fn file ->
        assert file =~ " Routes.blog_post_path(@conn"
      end

      assert_file "lib/phoenix_web/templates/blog/post/show.html.eex", fn file ->
        assert file =~ " Routes.blog_post_path(@conn"
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

      refute_file "lib/phoenix/blog.ex"
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

  test "with --no-context no warning is emitted when context exists", config do
    in_tmp_project config.test, fn ->
      Gen.Html.run(~w(Blog Post posts title:string))

      assert_file "lib/phoenix/blog.ex"
      assert_file "lib/phoenix/blog/post.ex"

      Gen.Html.run(~w(Blog Comment comments title:string --no-context))
      refute_received {:mix_shell, :info, ["You are generating into an existing context" <> _]}

      assert_file "test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end

      assert_file "lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
      end

      assert_file "lib/phoenix_web/views/comment_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentView"
      end
    end
  end

  test "with --no-schema skips schema file generation", config do
    in_tmp_project config.test, fn ->
      Gen.Html.run(~w(Blog Comment comments title:string --no-schema))

      assert_file "lib/phoenix/blog.ex"
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

  test "when more than 50 arguments are given", config do
    in_tmp_project config.test, fn ->
      long_attribute_list = 0..55 |> Enum.map(&("attribute#{&1}:string")) |> Enum.join(" ")
      Gen.Html.run(~w(Blog Post posts #{long_attribute_list}))

      assert_file "test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        refute file =~ "...}"
      end
    end
  end

  describe "inside umbrella" do
    test "without context_app generators config uses web dir", config do
      in_tmp_umbrella_project config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: nil)
        Gen.Html.run(~w(Accounts User users name:string))

        assert_file "lib/phoenix/accounts.ex"
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

        assert_file "another_app/lib/another_app/accounts.ex"
        assert_file "another_app/lib/another_app/accounts/user.ex"

        assert_file "lib/phoenix/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserController"
          assert file =~ "use Phoenix, :controller"
        end

        assert_file "lib/phoenix/templates/user/form.html.eex"
        assert_file "lib/phoenix/views/user_view.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserView"
        end

        assert_file "test/phoenix/controllers/user_controller_test.exs", fn file ->
          assert file =~ "defmodule Phoenix.UserControllerTest"
        end
      end
    end
  end
end
