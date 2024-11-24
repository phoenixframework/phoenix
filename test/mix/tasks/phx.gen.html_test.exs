Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.Gen.HtmlTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "invalid mix arguments", config do
    in_tmp_project(config.test, fn ->
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
    end)
  end

  test "generates html resource and handles existing contexts", config do
    one_day_in_seconds = 24 * 3600
    naive_datetime = %{NaiveDateTime.utc_now() | second: 0, microsecond: {0, 6}}
    datetime = %{DateTime.utc_now() | second: 0, microsecond: {0, 6}}

    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Post posts
                      title
                      slug:string:unique
                      votes:integer cost:decimal
                      content:text
                      tags:[array,text]
                      popular:boolean drafted_at:datetime
                      status:enum:[unpublished,published,deleted]
                      published_at:utc_datetime
                      published_at_usec:utc_datetime_usec
                      deleted_at:naive_datetime
                      deleted_at_usec:naive_datetime_usec
                      alarm:time
                      alarm_usec:time_usec
                      secret:uuid:redact
                      announcement_date:date
                      metadata:map
                      weight:float
                      user_id:references:table,users:column,id:type,id))

      assert_file("lib/phoenix/blog/post.ex")
      assert_file("lib/phoenix/blog.ex")
      assert_file("test/support/fixtures/blog_fixtures.ex")

      assert_file("test/phoenix/blog_test.exs", fn file ->
        assert file =~ "alarm: ~T[15:01:01]"
        assert file =~ "alarm_usec: ~T[15:01:01.000000]"
        assert file =~ "announcement_date: #{Date.utc_today() |> Date.add(-1) |> inspect()}"

        assert file =~
                 "deleted_at: #{naive_datetime |> NaiveDateTime.add(-one_day_in_seconds) |> NaiveDateTime.truncate(:second) |> inspect()}"

        assert file =~
                 "deleted_at_usec: #{naive_datetime |> NaiveDateTime.add(-one_day_in_seconds) |> inspect()}"

        assert file =~ "cost: \"22.5\""

        assert file =~
                 "published_at: #{datetime |> DateTime.add(-one_day_in_seconds) |> DateTime.truncate(:second) |> inspect()}"

        assert file =~
                 "published_at_usec: #{datetime |> DateTime.add(-one_day_in_seconds) |> inspect()}"

        assert file =~ "weight: 120.5"
        assert file =~ "status: :published"

        assert file =~ "assert post.announcement_date == #{inspect(Date.utc_today())}"

        assert file =~
                 "assert post.deleted_at == #{naive_datetime |> NaiveDateTime.truncate(:second) |> inspect()}"

        assert file =~ "assert post.deleted_at_usec == #{inspect(naive_datetime)}"

        assert file =~
                 "assert post.published_at == #{datetime |> DateTime.truncate(:second) |> inspect()}"

        assert file =~ "assert post.published_at_usec == #{inspect(datetime)}"
        assert file =~ "assert post.alarm == ~T[15:01:01]"
        assert file =~ "assert post.alarm_usec == ~T[15:01:01.000000]"
        assert file =~ "assert post.cost == Decimal.new(\"22.5\")"
        assert file =~ "assert post.weight == 120.5"
        assert file =~ "assert post.status == :published"
      end)

      assert_file("test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostControllerTest"
        assert file =~ ~s|~p"/posts|
      end)

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file(path, fn file ->
        assert file =~ "create table(\"posts\")"
        assert file =~ "add :title, :string"
        assert file =~ "add :content, :text"
        assert file =~ "add :status, :string"
        assert file =~ "add :popular, :boolean, default: false, null: false"
        assert file =~ "create index(\"posts\", [:slug], unique: true)"
      end)

      assert_file("lib/phoenix_web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ "Blog.get_post!"
        assert file =~ "Blog.list_posts"
        assert file =~ "Blog.create_post"
        assert file =~ "Blog.update_post"
        assert file =~ "Blog.delete_post"
        assert file =~ "Blog.change_post"
        assert file =~ ~s|redirect(to: ~p"/posts|
      end)

      assert_file("lib/phoenix_web/controllers/post_html.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostHTML"
      end)

      assert_file("lib/phoenix_web/controllers/post_html/index.html.heex", fn file ->
        assert file =~ ~s|~p"/posts|
      end)

      assert_file("lib/phoenix_web/controllers/post_html/new.html.heex", fn file ->
        assert file =~ ~S(action={~p"/posts"})
      end)

      assert_file("lib/phoenix_web/controllers/post_html/post_form.html.heex")

      assert_file("lib/phoenix_web/controllers/post_html/show.html.heex", fn file ->
        assert file =~ ~s|~p"/posts|
      end)

      assert_file("lib/phoenix_web/controllers/post_html/edit.html.heex", fn file ->
        assert file =~ ~S(action={~p"/posts/#{@post}"})
      end)

      assert_file("lib/phoenix_web/controllers/post_html/post_form.html.heex", fn file ->
        assert file =~ ~S(<.simple_form :let={f} for={@changeset} action={@action}>)

        assert file =~
                 """
                   <.input field={f[:title]} label="Title" type="text" />
                   <.input field={f[:slug]} label="Slug" type="text" />
                   <.input field={f[:votes]} label="Votes" type="number" />
                   <.input field={f[:cost]} label="Cost" type="number" step="any" />
                   <.input field={f[:content]} label="Content" type="textarea" />
                   <.input field={f[:tags]} label="Tags" type="select" options={["tags value", "updated tags value"]} multiple />
                   <.input field={f[:popular]} label="Popular" type="checkbox" />
                   <.input field={f[:drafted_at]} label="Drafted at" type="datetime-local" />
                   <.input field={f[:status]} label="Status" type="select" options={Ecto.Enum.values(Phoenix.Blog.Post, :status)} prompt="Choose a value" />
                   <.input field={f[:published_at]} label="Published at" type="datetime-local" />
                   <.input field={f[:published_at_usec]} label="Published at usec" type="text" />
                   <.input field={f[:deleted_at]} label="Deleted at" type="datetime-local" />
                   <.input field={f[:deleted_at_usec]} label="Deleted at usec" type="text" />
                   <.input field={f[:alarm]} label="Alarm" type="time" />
                   <.input field={f[:alarm_usec]} label="Alarm usec" type="text" />
                   <.input field={f[:secret]} label="Secret" type="text" />
                   <.input field={f[:announcement_date]} label="Announcement date" type="date" />
                   <.input field={f[:weight]} label="Weight" type="number" step="any" />
                   <.input field={f[:user_id]} label="User" type="text" />
                 """

        refute file =~ ~s(field={f[:metadata]})
      end)

      send(self(), {:mix_shell_input, :yes?, true})
      Gen.Html.run(~w(Blog Comment comments title:string:*))
      assert_received {:mix_shell, :info, ["You are generating into an existing context" <> _]}

      assert_file("lib/phoenix/blog/comment.ex")

      assert_file("test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end)

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")

      assert_file(path, fn file ->
        assert file =~ "create table(\"comments\")"
        assert file =~ "add :title, :string, null: false"
      end)

      assert_file("lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ "Blog.get_comment!"
        assert file =~ "Blog.list_comments"
        assert file =~ "Blog.create_comment"
        assert file =~ "Blog.update_comment"
        assert file =~ "Blog.delete_comment"
        assert file =~ "Blog.change_comment"
        assert file =~ ~s|redirect(to: ~p"/comments|
      end)

      assert_receive {:mix_shell, :info,
                      [
                        """

                        Add the resource to your browser scope in lib/phoenix_web/router.ex:

                            resources "/posts", PostController
                        """
                      ]}
    end)
  end

  test "generates into existing context without prompt with --merge-with-existing-context",
       config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Post posts))

      assert_file("lib/phoenix/blog.ex", fn file ->
        assert file =~ "def get_post!"
        assert file =~ "def list_posts"
        assert file =~ "def create_post"
        assert file =~ "def update_post"
        assert file =~ "def delete_post"
        assert file =~ "def change_post"
      end)

      Gen.Html.run(~w(Blog Comment comments --merge-with-existing-context))

      refute_received {:mix_shell, :info,
                       ["You are generating into an existing context" <> _notice]}

      assert_file("lib/phoenix/blog.ex", fn file ->
        assert file =~ "def get_comment!"
        assert file =~ "def list_comments"
        assert file =~ "def create_comment"
        assert file =~ "def update_comment"
        assert file =~ "def delete_comment"
        assert file =~ "def change_comment"
      end)
    end)
  end

  test "with --web namespace generates namespaced web modules and directories", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Post posts --web Blog))

      assert_file("test/phoenix_web/controllers/blog/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostControllerTest"
        assert file =~ ~s|~p"/blog/posts|
      end)

      assert_file("lib/phoenix_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ ~s|redirect(to: ~p"/blog/posts|
      end)

      assert_file("lib/phoenix_web/controllers/blog/post_html/edit.html.heex", fn file ->
        assert file =~ ~s|~p"/blog/posts|
      end)

      assert_file("lib/phoenix_web/controllers/blog/post_html/index.html.heex", fn file ->
        assert file =~ ~s|~p"/blog/posts|
      end)

      assert_file("lib/phoenix_web/controllers/blog/post_html/new.html.heex", fn file ->
        assert file =~ ~s|~p"/blog/posts|
      end)

      assert_file("lib/phoenix_web/controllers/blog/post_html/show.html.heex", fn file ->
        assert file =~ ~s|~p"/blog/posts|
      end)

      assert_file("lib/phoenix_web/controllers/blog/post_html.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostHTML"
      end)

      assert_receive {:mix_shell, :info,
                      [
                        """

                        Add the resource to your Blog :browser scope in lib/phoenix_web/router.ex:

                            scope "/blog", PhoenixWeb.Blog, as: :blog do
                              pipe_through :browser
                              ...
                              resources "/posts", PostController
                            end
                        """
                      ]}
    end)
  end

  test "with --no-context skips context and schema file generation", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Comment comments --no-context))

      refute_file("lib/phoenix/blog.ex")
      refute_file("lib/phoenix/blog/comment.ex")
      refute_file("test/phoenix/blog_test.ex")
      refute_file("test/support/fixtures/blog_fixtures.ex")
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file("test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end)

      assert_file("lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
      end)

      assert_file("lib/phoenix_web/controllers/comment_html.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentHTML"
      end)
    end)
  end

  test "with a matching plural and singular term", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Tracker Series series))

      assert_file("lib/phoenix_web/controllers/series_controller.ex", fn file ->
        assert file =~ "render(conn, :index, series_collection: series)"
      end)
    end)
  end

  test "with --no-context no warning is emitted when context exists", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Post posts))

      assert_file("lib/phoenix/blog.ex")
      assert_file("lib/phoenix/blog/post.ex")

      Gen.Html.run(~w(Blog Comment comments --no-context))
      refute_received {:mix_shell, :info, ["You are generating into an existing context" <> _]}

      assert_file("test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end)

      assert_file("lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
      end)

      assert_file("lib/phoenix_web/controllers/comment_html.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentHTML"
      end)
    end)
  end

  test "with --no-schema skips schema file generation", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Comment comments --no-schema))

      assert_file("lib/phoenix/blog.ex")
      refute_file("lib/phoenix/blog/comment.ex")
      assert Path.wildcard("priv/repo/migrations/*.exs") == []

      assert_file("test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end)

      assert_file("lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
      end)

      assert_file("lib/phoenix_web/controllers/comment_html.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentHTML"
      end)
    end)
  end

  test "when more than 50 arguments are given", config do
    in_tmp_project(config.test, fn ->
      long_attribute_list = Enum.map_join(0..55, " ", &"attribute#{&1}:string")
      Gen.Html.run(~w(Blog Post posts title:string:* #{long_attribute_list}))

      assert_file("test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        refute file =~ "...}"
      end)
    end)
  end

  describe "inside umbrella" do
    test "without context_app generators config uses web dir", config do
      in_tmp_umbrella_project(config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: nil)
        Gen.Html.run(~w(Accounts User users))

        assert_file("lib/phoenix/accounts.ex")
        assert_file("lib/phoenix/accounts/user.ex")

        assert_file("lib/phoenix_web/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserController"
          assert file =~ "use PhoenixWeb, :controller"
        end)

        assert_file("lib/phoenix_web/controllers/user_html.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserHTML"
        end)

        assert_file("test/phoenix_web/controllers/user_controller_test.exs", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserControllerTest"
        end)
      end)
    end

    test "raises with false context_app", config do
      in_tmp_umbrella_project(config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: false)

        assert_raise Mix.Error, ~r/no context_app configured/, fn ->
          Gen.Html.run(~w(Accounts User users name:string))
        end
      end)
    end

    test "with context_app generators config does not use web dir", config do
      in_tmp_umbrella_project(config.test, fn ->
        File.mkdir!("another_app")
        Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})

        Gen.Html.run(~w(Accounts User users))

        assert_file("another_app/lib/another_app/accounts.ex")
        assert_file("another_app/lib/another_app/accounts/user.ex")

        assert_file("lib/phoenix/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserController"
          assert file =~ "use Phoenix, :controller"
        end)

        assert_file("lib/phoenix/controllers/user_html.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserHTML"
        end)

        assert_file("test/phoenix/controllers/user_controller_test.exs", fn file ->
          assert file =~ "defmodule Phoenix.UserControllerTest"
        end)
      end)
    end

    test "allows enum type with at least one value", config do
      in_tmp_project(config.test, fn ->
        # Accepts first attribute to be required.
        send(self(), {:mix_shell_input, :yes?, true})
        Gen.Html.run(~w(Blog Post posts status:enum:[new]))

        assert_file("lib/phoenix_web/controllers/post_html/post_form.html.heex", fn file ->
          assert file =~ ~s|Ecto.Enum.values(Phoenix.Blog.Post, :status)|
        end)
      end)
    end
  end
end
