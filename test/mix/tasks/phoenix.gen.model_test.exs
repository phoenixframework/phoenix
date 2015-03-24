Code.require_file "../mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.Gen.ModelTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "generates model" do
    in_tmp "generates resource", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["user", "users", "name", "age:integer", "nicks:array:text",
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
    end
  end

  test "generates nested model" do
    in_tmp "generates nested model", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Admin.User", "users", "name:string"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_admin_user.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreateAdmin.User do"
        assert file =~ "create table(:users) do"
      end

      assert_file "web/models/admin/user.ex", fn file ->
        assert file =~ "defmodule Phoenix.Admin.User do"
        assert file =~ "use Phoenix.Web, :model"
        assert file =~ "schema \"users\" do"
      end
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Admin.User", "name:string", "foo:string"]
    end
  end
end
