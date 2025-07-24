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

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Gen.Html.run(~w(Blog Blog blogs))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Html.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Html.run(~w(Blog Post))
      end

      assert_raise Mix.Error, ~r/Enum type requires at least one value/, fn ->
        Gen.Html.run(~w(Blog Post posts status:enum))
      end

      assert_raise Mix.Error, ~r/requires at least one attribute/, fn ->
        Gen.Html.run(~w(Blog Post posts))
      end
    end)
  end

  test "generates html resource and handles existing contexts", config do
    one_day_in_seconds = 24 * 3600
    naive_datetime = %{NaiveDateTime.utc_now() | second: 0, microsecond: {0, 6}}
    datetime = %{DateTime.utc_now() | second: 0, microsecond: {0, 6}}

    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Post posts title content:text slug:unique votes:integer cost:decimal
                      tags:array:text popular:boolean drafted_at:datetime
                      status:enum:unpublished:published:deleted
                      published_at:utc_datetime
                      published_at_usec:utc_datetime_usec
                      deleted_at:naive_datetime
                      deleted_at_usec:naive_datetime_usec
                      alarm:time
                      alarm_usec:time_usec
                      secret:uuid:redact announcement_date:date alarm:time
                      metadata:map
                      weight:float user_id:references:users
                     ))

      assert_file("lib/phoenix/blog/post.ex")
      assert_file("lib/phoenix/blog.ex")

      assert_file("test/phoenix/blog_test.exs", fn file ->
        assert file =~ "alarm: ~T[15:01:01]"
        assert file =~ "alarm_usec: ~T[15:01:01.000000]"
        assert file =~ "announcement_date: #{Date.utc_today() |> Date.add(-1) |> inspect()}"

        assert file =~
                 "deleted_at: #{naive_datetime |> NaiveDateTime.add(-one_day_in_seconds) |> NaiveDateTime.truncate(:second) |> inspect()}"

        assert file =~
                 "deleted_at_usec: #{naive_datetime |> NaiveDateTime.add(-one_day_in_seconds) |> inspect()}"

        assert file =~ "cost: \"120.5\""

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
        assert file =~ "assert post.cost == Decimal.new(\"120.5\")"
        assert file =~ "assert post.weight == 120.5"
        assert file =~ "assert post.status == :published"
      end)

      assert_file("test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostControllerTest"
        assert file =~ ~s|~p"/posts|
      end)

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file(path, fn file ->
        assert file =~ "create table(:posts)"
        assert file =~ "add :title, :string"
        assert file =~ "add :content, :text"
        assert file =~ "add :status, :string"
        assert file =~ "create unique_index(:posts, [:slug])"
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
        assert file =~ ~S(<.form :let={f} for={@changeset} action={@action}>)
        assert file =~ ~s(<.input field={f[:title]} type="text")
        assert file =~ ~s(<.input field={f[:content]} type="textarea")
        assert file =~ ~s(<.input field={f[:votes]} type="number")
        assert file =~ ~s(<.input field={f[:cost]} type="number" label="Cost" step="any")

        assert file =~ """
                 <.input
                   field={f[:tags]}
                   type="select"
                   multiple
               """

        assert file =~ ~s(<.input field={f[:popular]} type="checkbox")
        assert file =~ ~s(<.input field={f[:drafted_at]} type="datetime-local")
        assert file =~ ~s(<.input field={f[:published_at]} type="datetime-local")
        assert file =~ ~s(<.input field={f[:deleted_at]} type="datetime-local")
        assert file =~ ~s(<.input field={f[:announcement_date]} type="date")
        assert file =~ ~s(<.input field={f[:alarm]} type="time")
        assert file =~ ~s(<.input field={f[:secret]} type="text" label="Secret" />)
        refute file =~ ~s(field={f[:metadata]})

        assert file =~ """
                 <.input
                   field={f[:status]}
                   type="select"
               """

        assert file =~ ~s|Ecto.Enum.values(Phoenix.Blog.Post, :status)|

        refute file =~ ~s(<.input field={f[:user_id]})
      end)

      send(self(), {:mix_shell_input, :yes?, true})
      Gen.Html.run(~w(Blog Comment comments title:string))
      assert_received {:mix_shell, :info, ["You are generating into an existing context" <> _]}

      assert_file("lib/phoenix/blog/comment.ex")

      assert_file("test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end)

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")

      assert_file(path, fn file ->
        assert file =~ "create table(:comments)"
        assert file =~ "add :title, :string"
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

  test "generates without explicit context", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Post posts title content:text slug:unique votes:integer cost:decimal
                        tags:array:text popular:boolean drafted_at:datetime
                        status:enum:unpublished:published:deleted
                        published_at:utc_datetime
                        published_at_usec:utc_datetime_usec
                        deleted_at:naive_datetime
                        deleted_at_usec:naive_datetime_usec
                        alarm:time
                        alarm_usec:time_usec
                        secret:uuid:redact announcement_date:date alarm:time
                        metadata:map
                        weight:float user_id:references:users
                      ))

      assert_file("lib/phoenix/posts/post.ex")
      assert_file("lib/phoenix/posts.ex")

      assert_file("test/phoenix/posts_test.exs", fn file ->
        assert file =~ "alarm: ~T[15:01:01]"
        assert file =~ "alarm_usec: ~T[15:01:01.000000]"
        assert file =~ "announcement_date: #{Date.utc_today() |> Date.add(-1) |> inspect()}"
      end)
    end)
  end

  test "generates into existing context without prompt with --merge-with-existing-context",
       config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Post posts title))

      assert_file("lib/phoenix/blog.ex", fn file ->
        assert file =~ "def get_post!"
        assert file =~ "def list_posts"
        assert file =~ "def create_post"
        assert file =~ "def update_post"
        assert file =~ "def delete_post"
        assert file =~ "def change_post"
      end)

      Gen.Html.run(~w(Blog Comment comments message:string --merge-with-existing-context))

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
      Gen.Html.run(~w(Blog Post posts title:string --web Blog))

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

                            scope "/blog", PhoenixWeb.Blog do
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
      Gen.Html.run(~w(Blog Comment comments title:string --no-context))

      refute_file("lib/phoenix/blog.ex")
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

  test "with a matching plural and singular term", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Tracker Series series value:integer))

      assert_file("lib/phoenix_web/controllers/series_controller.ex", fn file ->
        assert file =~ "render(conn, :index, series_collection: series)"
      end)
    end)
  end

  test "with --no-context no warning is emitted when context exists", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Post posts title:string))

      assert_file("lib/phoenix/blog.ex")
      assert_file("lib/phoenix/blog/post.ex")

      Gen.Html.run(~w(Blog Comment comments title:string --no-context))
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
      Gen.Html.run(~w(Blog Comment comments title:string --no-schema))

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
      Gen.Html.run(~w(Blog Post posts #{long_attribute_list}))

      assert_file("test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        refute file =~ "...}"
      end)
    end)
  end

  test "with custom primary key", config do
    in_tmp_project(config.test, fn ->
      Gen.Html.run(~w(Blog Post posts title:string --primary-key post_id))

      assert_file("lib/phoenix_web/controllers/post_controller.ex", fn file ->
        assert file =~ ~s[%{"post_id" => post_id}]
        assert file =~ ~s[%{"post_id" => post_id, "post" => post_params}]
        assert file =~ ~s[Blog.get_post!(post_id)]
      end)

      assert_file("lib/phoenix_web/controllers/post_html/show.html.heex", fn file ->
        assert file =~ ~S(Post {@post.post_id})
      end)

      assert_file("lib/phoenix_web/controllers/post_html/edit.html.heex", fn file ->
        assert file =~ ~S(Edit Post {@post.post_id})
      end)
    end)
  end

  describe "inside umbrella" do
    test "without context_app generators config uses web dir", config do
      in_tmp_umbrella_project(config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: nil)
        Gen.Html.run(~w(Accounts User users name:string))

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

        Gen.Html.run(~w(Accounts User users name:string))

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
        Gen.Html.run(~w(Blog Post posts status:enum:new))

        assert_file("lib/phoenix_web/controllers/post_html/post_form.html.heex", fn file ->
          assert file =~ ~s|Ecto.Enum.values(Phoenix.Blog.Post, :status)|
        end)
      end)
    end

    test "respect route_prefix in scopes", config do
      in_tmp_project(config.test, fn ->
        with_scope_env(
          :phoenix,
          [
            organization: [
              module: Phoenix.Organizations.Scope,
              assign_key: :current_organization,
              access_path: [:organization, :id],
              route_access_path: [:organization, :slug],
              route_prefix: "/orgs/:slug"
            ]
          ],
          fn ->
            Gen.Html.run(~w(Blog Post posts title:string --scope organization))

            assert_file("lib/phoenix_web/controllers/post_controller.ex", fn file ->
              assert file =~
                       ~s|redirect(to: ~p"/orgs/\#{conn.assigns.current_organization.organization.slug}/posts|
            end)

            assert_file("lib/phoenix_web/controllers/post_html/index.html.heex", fn file ->
              assert file =~
                       ~s|href={~p"/orgs/\#{@current_organization.organization.slug}/posts/new"|

              assert file =~
                       ~s|navigate={~p"/orgs/\#{@current_organization.organization.slug}/posts/|
            end)

            assert_file("lib/phoenix_web/controllers/post_html/show.html.heex", fn file ->
              assert file =~
                       ~s|navigate={~p"/orgs/\#{@current_organization.organization.slug}/posts"|
            end)

            assert_file("lib/phoenix_web/controllers/post_html/edit.html.heex", fn file ->
              assert file =~
                       ~s|action={~p"/orgs/\#{@current_organization.organization.slug}/posts/\#{@post}"|
            end)

            assert_file("lib/phoenix_web/controllers/post_html/new.html.heex", fn file ->
              assert file =~
                       ~s|action={~p"/orgs/\#{@current_organization.organization.slug}/posts"|
            end)

            assert_file("test/phoenix_web/controllers/post_controller_test.exs", fn file ->
              assert file =~ ~s|~p"/orgs/\#{scope.organization.slug}/posts"|
              assert file =~ ~s|~p"/orgs/\#{scope.organization.slug}/posts/new"|
              assert file =~ ~s|~p"/orgs/\#{scope.organization.slug}/posts/\#{post}"|
              assert file =~ ~s|~p"/orgs/\#{scope.organization.slug}/posts/\#{post}/edit"|
            end)
          end
        )
      end)
    end
  end
end
