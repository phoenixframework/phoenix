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

      assert_file "test/blog_test.exs", fn file ->
        assert file =~ "use Phoenix.DataCase"
      end

      assert_file "test/web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostControllerTest"
      end

      assert [_] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

      assert_file "lib/phoenix/web/controllers/fallback_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Web.FallbackController"
      end

      assert_file "lib/phoenix/web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Blog.get_post!"
        assert file =~ "Blog.list_posts"
        assert file =~ "Blog.create_post"
        assert file =~ "Blog.update_post"
        assert file =~ "Blog.delete_post"
      end
    end
  end

  test "with binary_id properly generates controller test", config do
    in_tmp_project config.test, fn ->
      with_generator_env [binary_id: true, sample_binary_id: "abcd"], fn ->
        Gen.Json.run(~w(Blog Post posts))

        assert_file "test/web/controllers/post_controller_test.exs", fn file ->
          assert file =~ ~S|post_path(conn, :show, "abcd")|
        end
      end

      with_generator_env [binary_id: true], fn ->
        Gen.Json.run(~w(Blog Post posts))

        assert_file "test/web/controllers/post_controller_test.exs", fn file ->
          assert file =~ ~S|post_path(conn, :show, "11111111-1111-1111-1111-111111111111")|
        end
      end
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Gen.Json.run(~w(Blog Post title:string))
    end
  end

  test "plural can't have uppercased characters or camelized format" do
    assert_raise Mix.Error, fn ->
      Gen.Json.run(~w(Blog Post Posts title:string))
    end

    assert_raise Mix.Error, fn ->
      Gen.Json.run(~w(Blog Post BlogPosts title:string))
    end
  end
end
