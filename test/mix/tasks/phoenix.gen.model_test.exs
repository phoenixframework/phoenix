Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.Dup do
end

defmodule Phoenix.Article do
  def __schema__(:source), do: "articles"
end

defmodule Mix.Tasks.Phoenix.Gen.ModelTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear
    :ok
  end

  test "generates model" do
    in_tmp "generates model", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["user", "users", "name", "age:integer", "nicks:array:text",
                                       "famous:boolean", "born_at:datetime", "secret:uuid", "desc:text"]

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
        assert file =~ "add :desc, :text"
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
        assert file =~ "field :desc, :string"
        assert file =~ "timestamps"
        assert file =~ "def changeset"
        assert file =~ "~w(name age nicks famous born_at secret desc)"
      end

      assert_file "test/models/user_test.exs", fn file ->
        assert file =~ "defmodule Phoenix.UserTest"
        assert file =~ "use Phoenix.ModelCase"

        assert file =~ ~S|@valid_params %{"age" => 42|
        assert file =~ ~S|changeset(%User{}, @valid_params)|
        assert file =~ ~S|assert changeset.valid?|

        assert file =~ ~S|@invalid_params %{}|
        assert file =~ ~S|changeset(%User{}, @invalid_params)|
        assert file =~ ~S|refute changeset.valid?|
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

  test "generates belongs_to associations with association table provided by user" do
    in_tmp "generates belongs_to associations", fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Post", "posts", "title", "user_id:references:users"]

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_post.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePost do"
        assert file =~ "create table(:posts) do"
        assert file =~ "add :title, :string"
        assert file =~ "add :user_id, references(:users)"
      end

      assert_file "web/models/post.ex", fn file ->
        assert file =~ "defmodule Phoenix.Post do"
        assert file =~ "use Phoenix.Web, :model"
        assert file =~ "schema \"posts\" do"
        assert file =~ "field :title, :string"
        assert file =~ "belongs_to :user, Phoenix.User"
      end
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Admin.User", "name:string", "foo:string"]
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, fn ->
      Mix.Tasks.Phoenix.Gen.Model.run ["Dup", "dups"]
    end
  end
end
