Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule PhoenixWeb.DupView do
end

defmodule Mix.Tasks.Phx.Gen.ViewTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates view" do
    in_tmp_project "generates view", fn ->
      Gen.View.run ["Posts"]

      assert_file "lib/phoenix_web/views/posts_view.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.PostsView do|
        assert file =~ ~S|use PhoenixWeb, :view|
      end
    end
  end

  test "in an umbrella with a context_app, generates the files" do
    in_tmp_umbrella_project "generates views", fn ->
      Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})
      Gen.View.run ["posts"]
      assert_file "lib/phoenix/views/posts_view.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.PostsView do|
        assert file =~ ~S|use PhoenixWeb, :view|
      end
    end
  end

  test "generates nested view" do
    in_tmp_project "generates nested view", fn ->
      Gen.View.run ["Admin.Posts"]

      assert_file "lib/phoenix_web/views/admin/posts_view.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Admin.PostsView do|
        assert file =~ ~S|use PhoenixWeb, :view|
      end
    end
  end

  test "passing no args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.View.run []
    end
  end

  test "passing extra args raises error" do
    assert_raise Mix.Error, fn ->
      Gen.View.run ["Admin.Posts", "new_message"]
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, ~r/DupView is already taken/, fn ->
      Gen.View.run ["Dup"]
    end
  end
end
