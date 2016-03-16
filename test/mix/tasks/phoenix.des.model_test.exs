Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.Des.ModelTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "destroys model" do
    in_tmp "destroys model", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["user", "users", "name", "age:integer", "nicks:array:text",
                                       "famous:boolean", "born_at:datetime", "secret:uuid", "desc:text",
                                       "blob:binary"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Model.run ["user", "users"]

      refute_file migration
      refute_file "web/models/user.ex"
      refute_file "test/models/user_test.exs"
    end
  end

  test "does not destroy model in prompt declined" do
    in_tmp "destroys model", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["user", "users", "name", "age:integer", "nicks:array:text",
                                       "famous:boolean", "born_at:datetime", "secret:uuid", "desc:text",
                                       "blob:binary"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_user.exs")

      send self(), {:mix_shell_input, :yes?, false}
      Mix.Tasks.Phoenix.Des.Model.run ["user", "users"]

      assert_file migration
      assert_file "web/models/user.ex"
      assert_file "test/models/user_test.exs"
    end
  end

  test "destroys nested model" do
    in_tmp "destroys nested model", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Admin.User", "users", "name:string"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_admin_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Model.run ["Admin.User", "users"]

      refute_file migration
      refute_file "web/models/admin/user.ex"
    end
  end

  test "destroys model with details" do
    in_tmp "destroys model with details", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Admin.User", "users", "name:string"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_admin_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Model.run ["Admin.User", "users", "name:string"]

      refute_file migration
      refute_file "web/models/admin/user.ex"
    end
  end

  test "destroys model with only singular arg" do
    in_tmp "destroys model with only singular arg", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Admin.User", "users", "name:string"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_admin_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Model.run ["Admin.User"]

      refute_file migration
      refute_file "web/models/admin/user.ex"
    end
  end

  test "skips destroying migration with --no-migration option" do
    in_tmp "skips destroying migration with -no-migration option", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Post", "posts"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_post.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Model.run ["Post", "posts", "--no-migration"]

      assert_file migration
    end
  end

  test "destroys model even if migration missing" do
    in_tmp "destroys model even if migration missing", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Post", "posts", "--no-migration"]

      assert [] = Path.wildcard("priv/repo/migrations/*_create_post.exs")
      assert_file "web/models/post.ex"

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Model.run ["Post", "posts"]

      refute_file "web/models/post.ex"
    end
  end

  test "uses defaults from :generators configuration for destroying" do
    in_tmp "uses defaults from generators configuration (migration) for destroying", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Post", "posts"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_post.exs")

      with_generators_config [migration: false], fn ->
        send self(), {:mix_shell_input, :yes?, true}
        Mix.Tasks.Phoenix.Des.Model.run ["Post", "posts"]

        assert_file migration
      end
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Des.Model.run ["Admin.User", "name:string", "foo:string"]
    end
  end

  test "plural can't have uppercased characters or camelized format" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Des.Html.run ["Admin.User", "Users", "foo:string"]
    end

    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Des.Html.run ["Admin.User", "AdminUsers", "foo:string"]
    end
  end

  defp with_generators_config(config, fun) do
    old_value = Application.get_env(:phoenix, :generators, [])
    try do
      Application.put_env(:phoenix, :generators, config)
      fun.()
    after
      Application.put_env(:phoenix, :generators, old_value)
    end
  end
end
