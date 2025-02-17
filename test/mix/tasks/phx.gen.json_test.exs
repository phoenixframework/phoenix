Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.Gen.JsonTest do
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
        Gen.Json.run(~w(blog Post posts title:string))
      end

      assert_raise Mix.Error, ~r/Expected the schema, "posts", to be a valid module name/, fn ->
        Gen.Json.run(~w(Post posts title:string))
      end

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Gen.Json.run(~w(Blog Blog blogs))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Json.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Json.run(~w(Blog Post))
      end
    end)
  end

  test "generates json resource", config do
    one_day_in_seconds = 24 * 3600

    naive_datetime =
      %{NaiveDateTime.utc_now() | second: 0, microsecond: {0, 6}}
      |> NaiveDateTime.add(-one_day_in_seconds)

    datetime =
      %{DateTime.utc_now() | second: 0, microsecond: {0, 6}}
      |> DateTime.add(-one_day_in_seconds)

    in_tmp_project(config.test, fn ->
      Gen.Json.run(~w(Blog Post posts title slug:unique votes:integer cost:decimal
                     tags:array:text popular:boolean drafted_at:datetime
                     params:map
                     published_at:utc_datetime
                     published_at_usec:utc_datetime_usec
                     deleted_at:naive_datetime
                     deleted_at_usec:naive_datetime_usec
                     alarm:time
                     alarm_usec:time_usec
                     secret:uuid:redact announcement_date:date
                     weight:float user_id:references:users))

      assert_file("lib/phoenix/blog/post.ex")
      assert_file("lib/phoenix/blog.ex")

      assert_file("test/phoenix/blog_test.exs", fn file ->
        assert file =~ "use Phoenix.DataCase"
      end)

      assert_file("test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostControllerTest"

        assert file =~ """
                     assert %{
                              "id" => ^id,
                              "alarm" => "14:00:00",
                              "alarm_usec" => "14:00:00.000000",
                              "announcement_date" => "#{Date.add(Date.utc_today(), -1)}",
                              "cost" => "120.5",
                              "deleted_at" => "#{naive_datetime |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()}",
                              "deleted_at_usec" => "#{NaiveDateTime.to_iso8601(naive_datetime)}",
                              "drafted_at" => "#{datetime |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601()}",
                              "params" => %{},
                              "popular" => true,
                              "published_at" => "#{datetime |> DateTime.truncate(:second) |> DateTime.to_iso8601()}",
                              "published_at_usec" => "#{DateTime.to_iso8601(datetime)}",
                              "secret" => "7488a646-e31f-11e4-aace-600308960662",
                              "slug" => "some slug",
                              "tags" => [],
                              "title" => "some title",
                              "votes" => 42,
                              "weight" => 120.5
                            } = json_response(conn, 200)["data"]
               """
      end)

      assert [_] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file("lib/phoenix_web/controllers/fallback_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.FallbackController"
      end)

      assert_file("lib/phoenix_web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ "Blog.get_post!"
        assert file =~ "Blog.list_posts"
        assert file =~ "Blog.create_post"
        assert file =~ "Blog.update_post"
        assert file =~ "Blog.delete_post"
        assert file =~ ~s|~p"/api/posts|
      end)

      assert_receive {:mix_shell, :info,
                      [
                        """

                        Add the resource to the "/api" scope in lib/phoenix_web/router.ex:

                            resources "/posts", PostController, except: [:new, :edit]
                        """
                      ]}
    end)
  end

  test "generates into existing context without prompt with --merge-with-existing-context",
       config do
    in_tmp_project(config.test, fn ->
      Gen.Json.run(~w(Blog Post posts title))

      assert_file("lib/phoenix/blog.ex", fn file ->
        assert file =~ "def get_post!"
        assert file =~ "def list_posts"
        assert file =~ "def create_post"
        assert file =~ "def update_post"
        assert file =~ "def delete_post"
        assert file =~ "def change_post"
      end)

      Gen.Json.run(~w(Blog Comment comments message:string --merge-with-existing-context))

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

  test "when more than 50 arguments are given", config do
    in_tmp_project(config.test, fn ->
      long_attribute_list = Enum.map_join(0..55, " ", &"attribute#{&1}:string")
      Gen.Json.run(~w(Blog Post posts #{long_attribute_list}))

      assert_file("test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        refute file =~ "...}"
      end)
    end)
  end

  test "with json --web namespace generates namespaced web modules and directories", config do
    in_tmp_project(config.test, fn ->
      Gen.Json.run(~w(Blog Post posts title:string --web Blog))

      assert_file("test/phoenix_web/controllers/blog/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostControllerTest"
        assert file =~ ~s|~p"/api/blog/posts|
      end)

      assert_file("lib/phoenix_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ ~s|~p"/api/blog/posts|
      end)

      assert_file("lib/phoenix_web/controllers/blog/post_json.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostJSON"
      end)

      assert_file("lib/phoenix_web/controllers/changeset_json.ex", fn file ->
        assert file =~ "Ecto.Changeset.traverse_errors(changeset, &translate_error/1)"
      end)

      assert_receive {:mix_shell, :info,
                      [
                        """

                        Add the resource to your Blog :api scope in lib/phoenix_web/router.ex:

                            scope "/blog", PhoenixWeb.Blog, as: :blog do
                              pipe_through :api
                              ...
                              resources "/posts", PostController
                            end
                        """
                      ]}
    end)
  end

  test "with --no-context skips context and schema file generation", config do
    in_tmp_project(config.test, fn ->
      Gen.Json.run(~w(Blog Comment comments title:string --no-context))

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

      assert_file("lib/phoenix_web/controllers/comment_json.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentJSON"
      end)
    end)
  end

  test "with --no-context no warning is emitted when context exists", config do
    in_tmp_project(config.test, fn ->
      Gen.Json.run(~w(Blog Post posts title:string))

      assert_file("lib/phoenix/blog.ex")
      assert_file("lib/phoenix/blog/post.ex")

      Gen.Json.run(~w(Blog Comment comments title:string --no-context))
      refute_received {:mix_shell, :info, ["You are generating into an existing context" <> _]}

      assert_file("test/phoenix_web/controllers/comment_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentControllerTest"
      end)

      assert_file("lib/phoenix_web/controllers/comment_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentController"
        assert file =~ "use PhoenixWeb, :controller"
      end)

      assert_file("lib/phoenix_web/controllers/comment_json.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentJSON"
      end)
    end)
  end

  test "with --no-schema skips schema file generation", config do
    in_tmp_project(config.test, fn ->
      Gen.Json.run(~w(Blog Comment comments title:string --no-schema))

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

      assert_file("lib/phoenix_web/controllers/comment_json.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentJSON"
      end)
    end)
  end

  describe "inside umbrella" do
    test "without context_app generators config uses web dir", config do
      in_tmp_umbrella_project(config.test, fn ->
        Gen.Json.run(~w(Accounts User users name:string))

        assert_file("lib/phoenix/accounts.ex")
        assert_file("lib/phoenix/accounts/user.ex")

        assert_file("lib/phoenix_web/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserController"
          assert file =~ "use PhoenixWeb, :controller"
        end)

        assert_file("lib/phoenix_web/controllers/user_json.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserJSON"
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
          Gen.Json.run(~w(Accounts User users name:string))
        end
      end)
    end

    test "with context_app generators config does not use web dir", config do
      in_tmp_umbrella_project(config.test, fn ->
        File.mkdir!("another_app")
        Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})

        Gen.Json.run(~w(Accounts User users name:string))

        assert_file("another_app/lib/another_app/accounts.ex")
        assert_file("another_app/lib/another_app/accounts/user.ex")

        assert_file("lib/phoenix/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserController"
          assert file =~ "use Phoenix, :controller"
        end)

        assert_file("lib/phoenix/controllers/user_json.ex", fn file ->
          assert file =~ "defmodule Phoenix.UserJSON"
        end)

        assert_file("test/phoenix/controllers/user_controller_test.exs", fn file ->
          assert file =~ "defmodule Phoenix.UserControllerTest"
        end)
      end)
    end
  end

  test "with existing core_components.ex file", config do
    in_tmp_project(config.test, fn ->
      File.mkdir_p!("lib/phoenix_web/components")

      File.write!("lib/phoenix_web/components/core_components.ex", """
      defmodule PhoenixWeb.CoreComponents do
      end
      """)

      [{module, _}] = Code.compile_file("lib/phoenix_web/components/core_components.ex")

      Gen.Json.run(~w(Blog Post posts title:string --web Blog))

      assert_file("lib/phoenix_web/controllers/changeset_json.ex", fn file ->
        assert file =~
                 "Ecto.Changeset.traverse_errors(changeset, &PhoenixWeb.CoreComponents.translate_error/1)"
      end)

      # Clean up test case specific compile artifact so it doesn't leak to other test cases
      :code.purge(module)
      :code.delete(module)
    end)
  end
end
