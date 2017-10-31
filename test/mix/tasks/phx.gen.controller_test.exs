Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule PhoenixWeb.DupController do
end

defmodule Mix.Tasks.Phx.Gen.ControllerTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates controller" do
    in_tmp_project "generates controller", fn ->
      Gen.Controller.run ["Posts"]

      assert_file "lib/phoenix_web/controllers/posts_controller.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.PostsController do|
        assert file =~ ~S|use PhoenixWeb, :controller|
      end

      assert_file "test/phoenix_web/controllers/posts_controller_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.PostsControllerTest|
        assert file =~ ~S|use PhoenixWeb.ConnCase|
        assert file =~ ~S|alias PhoenixWeb.PostsController|
      end
    end
  end

  test "in an umbrella with a context_app, generates the files" do
    in_tmp_umbrella_project "generates controllers", fn ->
      Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})
      Gen.Controller.run ["posts"]
      assert_file "lib/phoenix/controllers/posts_controller.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.PostsController do|
        assert file =~ ~S|use PhoenixWeb, :controller|
      end

      assert_file "test/phoenix/controllers/posts_controller_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.PostsControllerTest|
        assert file =~ ~S|use PhoenixWeb.ConnCase|
        assert file =~ ~S|alias PhoenixWeb.PostsController|
      end
    end
  end

  test "generates nested controller" do
    in_tmp_project "generates nested controller", fn ->
      Gen.Controller.run ["Admin.Posts"]

      assert_file "lib/phoenix_web/controllers/admin/posts_controller.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.PostsController do|
        assert file =~ ~S|use PhoenixWeb, :controller|
      end

      assert_file "test/phoenix_web/controllers/admin/posts_controller_test.exs", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.PostsControllerTest|
        assert file =~ ~S|use PhoenixWeb.ConnCase|
        assert file =~ ~S|alias PhoenixWeb.Admin.PostsController|
      end
    end
  end

  test "passing no args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Controller.run []
    end
  end

  test "passing extra args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.Controller.run ["Admin.Posts", "new_message"]
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, ~r/DupController is already taken/, fn ->
      Gen.Controller.run ["Dup"]
    end
  end
end
