Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.DupJsonContext do
end

defmodule Mix.Tasks.Phx.Gen.JsonTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "invalid mix arguments" do
    in_tmp_project "invalid mix arguments", fn ->
      assert_raise Mix.Error, ~r/expected the schema argument/, fn ->
        Gen.Json.run(~w(Post posts title:string))
      end

      assert_raise Mix.Error, ~r/expect a context module/, fn ->
        Gen.Json.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/expect a context module/, fn ->
        Gen.Json.run(~w(Blog Post))
      end
    end
  end

  test "name is already defined" do
    in_tmp_project "name is already defined", fn ->
      assert_raise Mix.Error, ~r/already taken/, fn ->
        Gen.Json.run ~w(DupJsonContext Post dups)
      end
    end
  end

  test "not inside single project" do
    in_tmp "not inside single project", fn ->
      assert_raise Mix.Error, ~r/can only be run inside an application directory/, fn ->
        Gen.Json.run ~w(Some Thing things)
      end
    end
  end

  test "generates json context" do
    in_tmp_project "generates json context", fn ->
      Gen.Json.run(["Blog", "Post", "posts", "title:string"])

      assert_file "lib/blog/post.ex"
      assert_file "lib/blog.ex"

      assert_file "test/blog_test.exs", fn file ->
        assert file =~ "use Phoenix.DataCase"
      end

      assert_file "test/web/controllers/post_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostControllerTest"
      end

      assert [_] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

      assert_file "lib/web/controllers/fallback_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Web.FallbackController"
      end

      assert_file "lib/web/controllers/post_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Web.PostController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Blog.get_post!"
        assert file =~ "Blog.list_posts"
        assert file =~ "Blog.create_post"
        assert file =~ "Blog.update_post"
        assert file =~ "Blog.delete_post"
        assert file =~ "Blog.change_post"
      end
    end
  end
end
