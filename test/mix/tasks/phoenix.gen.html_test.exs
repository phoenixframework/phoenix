Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.DupHTMLController do
end

defmodule Phoenix.DupHTMLView do
end

defmodule Mix.Tasks.Phoenix.Gen.HtmlTest do
  use ExUnit.Case
  import ExUnit.CaptureIO
  import MixHelper

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates html resource" do
    in_tmp "deprecated: generates html resource", fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Html.run ["user", "users", "name", "age:integer", "height:decimal",
                                        "nicks:array:text", "famous:boolean", "born_at:naive_datetime",
                                        "secret:uuid", "first_login:date", "alarm:time",
                                        "address_id:references:addresses"]
      end)
      assert_file "web/models/user.ex"
      assert_file "test/models/user_test.exs"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_user.exs")

      assert_file "web/controllers/user_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.UserController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Repo.get!"
      end

      assert_file "web/views/user_view.ex", fn file ->
        assert file =~ "defmodule Phoenix.UserView do"
        assert file =~ "use Phoenix.Web, :view"
      end

      assert_file "web/templates/user/edit.html.eex", fn file ->
        assert file =~ "action: user_path(@conn, :update, @user)"
      end

      assert_file "web/templates/user/form.html.eex", fn file ->
        assert file =~ ~s(<%= text_input f, :name, class: "form-control" %>)
        assert file =~ ~s(<%= number_input f, :age, class: "form-control" %>)
        assert file =~ ~s(<%= number_input f, :height, step: "any", class: "form-control" %>)
        assert file =~ ~s(<%= checkbox f, :famous, class: "checkbox" %>)
        assert file =~ ~s(<%= datetime_select f, :born_at, class: "form-control" %>)
        assert file =~ ~s(<%= text_input f, :secret, class: "form-control" %>)
        assert file =~ ~s(<%= label f, :name, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :age, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :height, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :famous, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :born_at, class: "control-label" %>)
        assert file =~ ~s(<%= label f, :secret, class: "control-label" %>)

        refute file =~ ~s(<%= label f, :address_id)
        refute file =~ ~s(<%= number_input f, :address_id)
        refute file =~ ":nicks"
      end

      assert_file "web/templates/user/index.html.eex", fn file ->
        assert file =~ "<th>Name</th>"
        assert file =~ "<%= for user <- @users do %>"
        assert file =~ "<td><%= user.name %></td>"
      end

      assert_file "web/templates/user/new.html.eex", fn file ->
        assert file =~ "action: user_path(@conn, :create)"
      end

      assert_file "web/templates/user/show.html.eex", fn file ->
        assert file =~ "<strong>Name:</strong>"
        assert file =~ "<%= @user.name %>"
      end

      assert_file "test/controllers/user_controller_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.UserControllerTest"
        assert file =~ "use Phoenix.ConnCase"

        assert file =~ ~S|@valid_attrs %{age: 42|
        assert file =~ ~S|@invalid_attrs %{}|
        refute file =~ ~S|address_id: nil|

        assert file =~ ~S|test "lists all entries on index"|
        assert file =~ ~S|conn = get conn, user_path(conn, :index)|
        assert file =~ ~S|assert html_response(conn, 200) =~ "Listing users"|

        assert file =~ ~S|test "renders form for new resources"|
        assert file =~ ~S|conn = get conn, user_path(conn, :new)|
        assert file =~ ~S|assert html_response(conn, 200) =~ "New user"|

        assert file =~ ~S|test "creates resource and redirects when data is valid"|
        assert file =~ ~S|conn = post conn, user_path(conn, :create), user: @valid_attrs|
        assert file =~ ~S|assert redirected_to(conn) == user_path(conn, :index)|
        assert file =~ ~r/creates.*when data is valid.*?assert Repo\.get_by\(User, @valid_attrs\).*?end/s

        assert file =~ ~S|test "does not create resource and renders errors when data is invalid"|
        assert file =~ ~S|conn = post conn, user_path(conn, :create), user: @invalid_attrs|

        assert file =~ ~S|test "shows chosen resource"|
        assert file =~ ~S|user = Repo.insert! %User{}|
        assert file =~ ~S|assert html_response(conn, 200) =~ "Show user"|

        assert file =~ ~S|test "renders form for editing chosen resource"|
        assert file =~ ~S|assert html_response(conn, 200) =~ "Edit user"|

        assert file =~ ~S|test "updates chosen resource and redirects when data is valid"|
        assert file =~ ~S|conn = put conn, user_path(conn, :update, user), user: @valid_attrs|
        assert file =~ ~r/updates.*when data is valid.*?assert Repo\.get_by\(User, @valid_attrs\).*?end/s

        assert file =~ ~S|test "does not update chosen resource and renders errors when data is invalid"|
        assert file =~ ~S|conn = put conn, user_path(conn, :update, user), user: @invalid_attrs|

        assert file =~ ~S|test "deletes chosen resource"|
        assert file =~ ~S|conn = delete conn, user_path(conn, :delete, user)|

        assert file =~ ~S|test "renders page not found when id is nonexistent"|
        assert file =~ ~S|user_path(conn, :show, -1)|
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/users", UserController)
    end
  end

  test "generates nested resource" do
    in_tmp "deprecated: generates nested resource", fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Html.run ["Admin.SuperUser", "super_users", "name:string"]
      end)

      assert_file "web/models/admin/super_user.ex"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_admin_super_user.exs")

      assert_file "web/controllers/admin/super_user_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.SuperUserController"
        assert file =~ "use Phoenix.Web, :controller"
        assert file =~ "Repo.get!"
      end

      assert_file "web/views/admin/super_user_view.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.SuperUserView do"
        assert file =~ "use Phoenix.Web, :view"
      end

      assert_file "web/templates/admin/super_user/edit.html.eex", fn file ->
        assert file =~ "<h2>Edit super user</h2>"
        assert file =~ "action: super_user_path(@conn, :update, @super_user)"
      end

      assert_file "web/templates/admin/super_user/form.html.eex", fn file ->
        assert file =~ ~s(<%= text_input f, :name, class: "form-control" %>)
      end

      assert_file "web/templates/admin/super_user/index.html.eex", fn file ->
        assert file =~ "<h2>Listing super users</h2>"
        assert file =~ "<th>Name</th>"
        assert file =~ "<%= for super_user <- @super_users do %>"
      end

      assert_file "web/templates/admin/super_user/new.html.eex", fn file ->
        assert file =~ "<h2>New super user</h2>"
        assert file =~ "action: super_user_path(@conn, :create)"
      end

      assert_file "web/templates/admin/super_user/show.html.eex", fn file ->
        assert file =~ "<h2>Show super user</h2>"
        assert file =~ "<strong>Name:</strong>"
        assert file =~ "<%= @super_user.name %>"
      end

      assert_file "test/controllers/admin/super_user_controller_test.exs", fn file ->
        assert file =~ ~S|assert html_response(conn, 200) =~ "Listing super users"|
        assert file =~ ~S|assert html_response(conn, 200) =~ "New super user"|
        assert file =~ ~S|assert html_response(conn, 200) =~ "Show super user"|
        assert file =~ ~S|assert html_response(conn, 200) =~ "Edit super user"|
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/admin/super_users", Admin.SuperUserController)
    end
  end

  test "generates html resource without model" do
    in_tmp "deprecated: generates html resource without model", fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Html.run ["Admin.User", "users", "--no-model", "name:string"]
      end)

      refute File.exists? "web/models/admin/user.ex"
      assert [] = Path.wildcard("priv/repo/migrations/*_create_admin_user.exs")

      assert_file "web/templates/admin/user/form.html.eex", fn file ->
        refute file =~ ~s(--no-model)
      end
    end
  end

  test "with binary_id properly generates controller test" do
    in_tmp "deprecated: with binary_id properly generates controller test", fn ->
      with_generator_env [binary_id: true, sample_binary_id: "abcd"], fn ->
        capture_io(:stderr, fn ->
          Mix.Tasks.Phoenix.Gen.Html.run ["User", "users"]
        end)

        assert_file "test/controllers/user_controller_test.exs", fn file ->
          assert file =~ ~S|user_path(conn, :show, "abcd")|
        end
      end

      with_generator_env [binary_id: true], fn ->
        capture_io(:stderr, fn ->
          Mix.Tasks.Phoenix.Gen.Html.run ["Post", "posts"]
        end)

        assert_file "test/controllers/post_controller_test.exs", fn file ->
          assert file =~ ~S|post_path(conn, :show, "11111111-1111-1111-1111-111111111111")|
        end
      end
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Html.run ["Admin.User", "name:string", "foo:string"]
      end)
    end
  end

  test "plural can't have uppercased characters or camelized format" do
    assert_raise Mix.Error, fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Html.run ["Admin.User", "Users", "foo:string"]
      end)
    end

    assert_raise Mix.Error, fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Html.run ["Admin.User", "AdminUsers", "foo:string"]
      end)
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Html.run ["DupHTML", "duphtmls"]
      end)
    end
  end
end
