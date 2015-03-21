Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.Gen.ResourceTest do
  use ExUnit.Case
  import MixHelper

  test "generates resource" do
    in_tmp "generates resource", fn ->
      Mix.Tasks.Phoenix.Gen.Resource.run ["user", "users", "name", "age:integer", "nicks:array:text",
                                          "famous:boolean", "born_at:datetime", "secret:uuid"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_user.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreateUser do"
        assert file =~ "create table(:users) do"
        assert file =~ "add :name, :string"
        assert file =~ "add :age, :integer"
        assert file =~ "add :nicks, {:array, :text}"
        assert file =~ "add :famous, :boolean, default: false"
        assert file =~ "add :born_at, :datetime"
        assert file =~ "add :secret, :uuid"
        assert file =~ "timestamps"
      end

      assert_file "web/controllers/user_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.UserController"
        assert file =~ "use Phoenix.Web, :controller"
      end

      assert_file "web/models/user.ex", fn file ->
        assert file =~ "defmodule Phoenix.User do"
        assert file =~ "use Phoenix.Web, :model"
        assert file =~ "schema \"users\" do"
        assert file =~ "field :name, :string"
        assert file =~ "field :age, :integer"
        assert file =~ "field :nicks, {:array, :string}"
        assert file =~ "field :famous, :boolean, default: false"
        assert file =~ "field :born_at, Ecto.DateTime"
        assert file =~ "field :secret, Ecto.UUID"
        assert file =~ "timestamps"
        assert file =~ "def changeset"
        assert file =~ "~w(name age nicks famous born_at secret)"
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
        assert file =~ ~s(<%= checkbox f, :famous, class: "form-control" %>)
        assert file =~ ~s(<%= datetime_select f, :born_at, class: "form-control" %>)
        assert file =~ ~s(<%= text_input f, :secret, class: "form-control" %>)
        refute file =~ ":nicks"
      end

      assert_file "web/templates/user/index.html.eex", fn file ->
        assert file =~ "<th>Name</th>"
        assert file =~ "<%= for user <- @users do %>"
      end

      assert_file "web/templates/user/new.html.eex", fn file ->
        assert file =~ "action: user_path(@conn, :create)"
      end

      assert_file "web/templates/user/show.html.eex", fn file ->
        assert file =~ "<strong>Name:</strong>"
        assert file =~ "<%= @user.name %>"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/users", UserController)
    end
  end

  test "generates nested resource" do
    in_tmp "generates nested resource", fn ->
      Mix.Tasks.Phoenix.Gen.Resource.run ["Admin.User", "users", "name:string"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_admin_user.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreateAdmin.User do"
        assert file =~ "create table(:users) do"
      end

      assert_file "web/controllers/admin/user_controller.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.UserController"
        assert file =~ "use Phoenix.Web, :controller"
      end

      assert_file "web/models/admin/user.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.User do"
        assert file =~ "use Phoenix.Web, :model"
        assert file =~ "schema \"users\" do"
      end

      assert_file "web/views/admin/user_view.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.UserView do"
        assert file =~ "use Phoenix.Web, :view"
      end

      assert_file "web/templates/admin/user/edit.html.eex", fn file ->
        assert file =~ "action: user_path(@conn, :update, @user)"
      end

      assert_file "web/templates/admin/user/form.html.eex", fn file ->
        assert file =~ ~s(<%= text_input f, :name, class: "form-control" %>)
      end

      assert_file "web/templates/admin/user/index.html.eex", fn file ->
        assert file =~ "<th>Name</th>"
        assert file =~ "<%= for user <- @users do %>"
      end

      assert_file "web/templates/admin/user/new.html.eex", fn file ->
        assert file =~ "action: user_path(@conn, :create)"
      end

      assert_file "web/templates/admin/user/show.html.eex", fn file ->
        assert file =~ "<strong>Name:</strong>"
        assert file =~ "<%= @user.name %>"
      end

      assert_received {:mix_shell, :info, ["\nAdd the resource" <> _ = message]}
      assert message =~ ~s(resources "/admin/users", Admin.UserController)
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Resource.run ["Admin.User", "name:string", "foo:string"]
    end
  end
end
