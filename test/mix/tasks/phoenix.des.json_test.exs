Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.Des.JsonTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "destroys json resource" do
    in_tmp "destroys json resource", fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["user", "users", "name", "age:integer", "height:decimal",
                                      "nicks:array:text", "famous:boolean", "born_at:datetime",
                                      "secret:uuid", "first_login:date", "alarm:time"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Json.run ["user", "users"]

      refute_file migration
      refute_file "web/models/user.ex"
      refute_file "test/models/user_test.exs"
      refute_file "web/controllers/user_controller.ex"
      refute_file "web/views/user_view.ex"
      refute_file "test/controllers/user_controller_test.exs"
    end
  end

  test "destroys nested resource" do
    in_tmp "destroys nested resource", fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["Admin.User", "users", "name:string"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_admin_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Json.run ["Admin.User", "users"]

      refute_file migration
      refute_file "web/models/admin/user.ex"
      refute_file "web/controllers/admin/user_controller.ex"
      refute_file "web/views/admin/user_view.ex"
    end
  end

  test "skips model destruction if asked" do
    in_tmp "skips model destruction if asked", fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["API.V1.User", "users", "name:string"]
      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_api_v1_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Json.run ["API.V1.User", "users", "--no-model"]

      assert_file migration
      assert_file "web/models/api/v1/user.ex"

      refute_file "web/controllers/api/v1/user_controller.ex"
      refute_file "web/views/api/v1/user_view.ex"
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Json.run ["Admin.User", "name:string", "foo:string"]
    end
  end

  test "plural can't have uppercased characters or camelized format" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Html.run ["Admin.User", "Users", "foo:string"]
    end

    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Html.run ["Admin.User", "AdminUsers", "foo:string"]
    end
  end
end
