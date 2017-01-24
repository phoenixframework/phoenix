Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.HtmlTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen
  alias Mix.Tasks.Phx.Gen.Html.Context

  setup do
    Mix.Task.clear()
    :ok
  end

  test "new context" do
    in_tmp "new context", fn ->
      assert %Context{} = context = Context.new("Blog", "Post")

      assert context == %Context{
        base_module: Phoenix,
        basename: "blog",
        dir: "lib/blog",
        file: "lib/blog.ex",
        module: Phoenix.Blog, pre_existing?: false,
        schema_file: "lib/blog/post.ex",
        pre_existing?: false,
        schema_module: Phoenix.Blog.Post}
    end
  end


  test "new existing context" do
    in_tmp "new existing context", fn ->
      File.mkdir_p!("lib/blog")
      File.write!("lib/blog.ex", """
      defmodule Phoenix.Blog do
      end
      """)
      assert %Context{pre_existing?: true} = Context.new("Blog", "Post")
    end
  end



  test "generates html context" do
    in_tmp "generates html context", fn ->
      Gen.Html.run(["Blog", "Post"])

      assert_file "web/models/user.ex"
      assert_file "test/models/user_test.exs"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_user.exs")

      assert_file "web/controllers/user_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.UserController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Repo.get!"
      end
    end
  end
end
