Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.Des.HtmlTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "destroys html resource" do
    in_tmp "destroys html resource", fn ->
      Mix.Tasks.Phoenix.Gen.Html.run ["user", "users", "name", "age:integer", "height:decimal",
                                      "nicks:array:text", "famous:boolean", "born_at:datetime",
                                      "secret:uuid", "first_login:date", "alarm:time",
                                      "address_id:references:addresses"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Html.run ["user", "users"]

      refute_file migration
      refute_file "web/models/user.ex"
      refute_file "test/models/user_test.exs"
      refute_file "web/controllers/user_controller.ex"
      refute_file "web/views/user_view.ex"
      refute_file "web/templates/user/edit.html.eex"
      refute_file "web/templates/user/form.html.eex"
      refute_file "web/templates/user/index.html.eex"
      refute_file "web/templates/user/new.html.eex"
      refute_file "web/templates/user/show.html.eex"
      refute_file "test/controllers/user_controller_test.exs"
    end
  end

  test "destroys nested resource" do
    in_tmp "destroys nested resource", fn ->
      Mix.Tasks.Phoenix.Gen.Html.run ["Admin.SuperUser", "super_users", "name:string"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_admin_super_user.exs")

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Html.run ["Admin.SuperUser", "super_users", "name:string"]

      refute_file migration
      refute_file "web/models/admin/super_user.ex"
      refute_file "web/controllers/admin/super_user_controller.ex"
      refute_file "web/views/admin/super_user_view.ex"
      refute_file "web/templates/admin/super_user/edit.html.eex"
      refute_file "web/templates/admin/super_user/form.html.eex"
      refute_file "web/templates/admin/super_user/index.html.eex"
      refute_file "web/templates/admin/super_user/new.html.eex"
      refute_file "web/templates/admin/super_user/show.html.eex"
      refute_file "test/controllers/admin/super_user_controller_test.exs"
    end
  end

  test "destroys html resource without model" do
    in_tmp "destroys html resource without model", fn ->
      Mix.Tasks.Phoenix.Gen.Html.run ["Admin.User", "users", "name:string"]

      assert_file "web/models/admin/user.ex"

      send self(), {:mix_shell_input, :yes?, true}
      Mix.Tasks.Phoenix.Des.Html.run ["Admin.User", "users", "--no-model"]

      assert_file "web/models/admin/user.ex"
      refute_file "web/templates/admin/user/form.html.eex"
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Des.Html.run ["Admin.User", "name:string", "foo:string"]
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
end
