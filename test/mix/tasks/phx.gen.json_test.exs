Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.JsonTest do
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
    end
  end

  test "generates json resource", config do
    in_tmp_project config.test, fn ->
      Gen.Json.run(["Blog", "Post", "posts", "title:string"])

      assert_file "lib/phoenix/blog/post.ex"
      assert_file "lib/phoenix/blog/blog.ex"

      assert_file "test/phoenix/blog/blog_test.exs", fn file ->
        assert file =~ "use Phoenix.DataCase"
      end

      assert_file "test/phoenix_web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostControllerTest"
      end

      assert [_] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file "lib/phoenix_web/controllers/fallback_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.FallbackController"
      end

      assert_file "lib/phoenix_web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ "Blog.get_post!"
        assert file =~ "Blog.list_posts"
        assert file =~ "Blog.create_post"
        assert file =~ "Blog.update_post"
        assert file =~ "Blog.delete_post"
        assert file =~ " Routes.post_path(conn"
      end

      assert_receive {:mix_shell, :info, ["""

      Add the resource to your :api scope in lib/phoenix_web/router.ex:

          resources "/posts", PostController, except: [:new, :edit]
      """]}
    end
  end

  test "with json --web namespace generates namedspaced web modules and directories", config do
    in_tmp_project config.test, fn ->
      Gen.Json.run(~w(Blog Post posts title:string --web Blog))

      assert_file "test/phoenix_web/controllers/blog/post_controller_test.exs", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostControllerTest"
        assert file =~ " Routes.blog_post_path(conn"
      end

      assert_file "lib/phoenix_web/controllers/blog/post_controller.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostController"
        assert file =~ "use PhoenixWeb, :controller"
        assert file =~ " Routes.blog_post_path(conn"
      end

      assert_file "lib/phoenix_web/views/blog/post_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.Blog.PostView"
      end

      assert_receive {:mix_shell, :info, ["""

      Add the resource to your Blog :api scope in lib/phoenix_web/router.ex:

          scope "/blog", PhoenixWeb.Blog do
            pipe_through :api
            ...
            resources "/posts", PostController
          end
      """]}
    end
  end

  test "with --no-context skips context and schema file generation", config do
    in_tmp_project config.test, fn ->
      Gen.Json.run(~w(Blog Comment comments title:string --no-context))

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

      assert_file "lib/phoenix_web/views/comment_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentView"
      end
    end
  end

  test "with --no-schema skips schema file generation", config do
    in_tmp_project config.test, fn ->
      Gen.Json.run(~w(Blog Comment comments title:string --no-schema))

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

      assert_file "lib/phoenix_web/views/comment_view.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.CommentView"
      end
    end
  end

  describe "inside umbrella" do
    test "without context_app generators config uses web dir", config do
      in_tmp_umbrella_project config.test, fn ->
        Gen.Json.run(~w(Accounts User users name:string))

        assert_file "lib/phoenix/accounts/accounts.ex"
        assert_file "lib/phoenix/accounts/user.ex"

        assert_file "lib/phoenix_web/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserController"
          assert file =~ "use PhoenixWeb, :controller"
        end

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
          Gen.Json.run(~w(Accounts User users name:string))
        end
      end
    end

    test "with context_app generators config does not use web dir", config do
      in_tmp_umbrella_project config.test, fn ->
        File.mkdir!("another_app")
        Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})

        Gen.Json.run(~w(Accounts User users name:string))

        assert_file "another_app/lib/another_app/accounts/accounts.ex"
        assert_file "another_app/lib/another_app/accounts/user.ex"

        assert_file "lib/phoenix/controllers/user_controller.ex", fn file ->
          assert file =~ "defmodule PhoenixWeb.UserController"
          assert file =~ "use PhoenixWeb, :controller"
        end

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
