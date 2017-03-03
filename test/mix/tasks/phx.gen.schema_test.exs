Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.DupSchema do
end

defmodule Mix.Tasks.Phx.Gen.SchemaTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen
  alias Mix.Phoenix.Schema

  setup do
    Mix.Task.clear()
    :ok
  end

  test "build" do
    in_tmp_project "build", fn ->
      schema = Gen.Schema.build(~w(Blog.Post posts title:string))

      assert %Schema{
        alias: Post,
        module: Phoenix.Blog.Post,
        repo: Phoenix.Repo,
        file: "lib/phoenix/blog/post.ex",
        migration?: true,
        migration_defaults: %{title: ""},
        plural: "posts",
        singular: "post",
        human_plural: "Posts",
        human_singular: "Post",
        attrs: [title: :string],
        types: %{title: :string},
        defaults: %{title: ""},
      } = schema
    end
  end

  test "generates custom table name", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts --table cms_posts))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

      assert_file migration, fn file ->
        assert file =~ "create table(:cms_posts) do"
      end
    end
  end

  test "generates nested context", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Admin.User users name:string))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_admin_user.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePhoenix.Blog.Admin.User do"
        assert file =~ "create table(:users) do"
      end

      assert_file "lib/phoenix/blog/admin/user.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Admin.User do"
        assert file =~ "schema \"users\" do"
      end
    end
  end

  test "generates belongs_to associations with association table provided by user", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title user_id:references:users))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

      assert_file migration, fn file ->
        assert file =~ "add :user_id, {:references, :users}"
      end

      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "field :user_id, {:references, :users}"
      end
    end
  end

  test "generates unique_index" , config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title:unique unique_int:integer:unique))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePhoenix.Blog.Post do"
        assert file =~ "create table(:posts) do"
        assert file =~ "add :title, :string"
        assert file =~ "add :unique_int, :integer"
        assert file =~ "create unique_index(:posts, [:title])"
        assert file =~ "create unique_index(:posts, [:unique_int])"
      end

      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Post do"
        assert file =~ "schema \"posts\" do"
        assert file =~ "field :title, :string"
        assert file =~ "field :unique_int, :integer"
      end
    end
  end

  test "generates indices on belongs_to associations", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title user_id:references:users unique_post_id:references:posts:unique))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePhoenix.Blog.Post do"
        assert file =~ "create table(:posts) do"
        assert file =~ "add :user_id, {:references, :users}"
        assert file =~ "add :unique_post_id, {:references, :posts}"
        assert file =~ "create unique_index(:posts, [:unique_post_id])"
      end

      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Post do"
        assert file =~ "field :user_id, {:references, :users}"
        assert file =~ "field :unique_post_id, {:references, :posts}"
      end
    end
  end

  test "plural can't contain a colon", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/plural/, fn ->
        Gen.Schema.run ~w(Admin.User name:string foo:string)
      end
    end
  end

  test "plural can't have uppercased characters or camelized format", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/all lowercase/, fn ->
        Gen.Schema.run ~w(Admin.User Users foo:string)
      end

      assert_raise Mix.Error, ~r/all lowercase/, fn ->
        Gen.Schema.run ~w(Admin.User AdminUsers foo:string)
      end
    end
  end

  test "name is already defined", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/already taken/, fn ->
        Gen.Schema.run ~w(DupSchema schemas)
      end
    end
  end

  test "table name missing from references", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/missing/, fn ->
        Gen.Schema.run(~w(Blog.Post posts user_id:references))
      end
    end
  end

  test "generates schema", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post blog_posts title:string))
      assert_file "lib/phoenix/blog/post.ex"

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")
      assert_file migration, fn file ->
        assert file =~ "create table(:blog_posts) do"
      end
    end
  end

  test "generates migration with binary_id", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title user_id:references:users --binary-id))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

      assert_file migration, fn file ->
        assert file =~ "create table(:posts, primary_key: false) do"
        assert file =~ "add :id, :binary_id, primary_key: true"
        assert file =~ "add :user_id, {:references, :users}"
      end
    end
  end

  test "skips migration with --no-migration option", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts --no-migration))

      assert [] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")
    end
  end

  test "table name omitted", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, fn ->
        Gen.Schema.run(~w(Blog.Post))
      end
    end
  end

  test "uses defaults from :generators configuration" do
    in_tmp_project "uses defaults from generators configuration (migration)", fn ->
      with_generator_env [migration: false], fn ->
        Gen.Schema.run(~w(Blog.Post posts))

        assert [] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")
      end
    end

    in_tmp_project "uses defaults from generators configuration (binary_id)", fn ->
      with_generator_env [binary_id: true], fn ->
        Gen.Schema.run(~w(Blog.Post posts))

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")

        assert_file migration, fn file ->
          assert file =~ "create table(:posts, primary_key: false) do"
          assert file =~ "add :id, :binary_id, primary_key: true"
        end
      end
    end
  end

  test "generates schema with proper datetime types" do
    Gen.Schema.run(~w(Blog.Comment comments title:string drafted_at:datetime published_at:naive_datetime edited_at:utc_datetime))

    assert_file "lib/phoenix/blog/comment.ex", fn file ->
      assert file =~ "field :drafted_at, :naive_datetime"
      assert file =~ "field :published_at, :naive_datetime"
      assert file =~ "field :edited_at, :utc_datetime"
    end

    assert [path] = Path.wildcard("priv/repo/migrations/*_create_blog_comment.exs")
    assert_file path, fn file ->
      assert file =~ "create table(:comments)"
      assert file =~ "add :drafted_at, :naive_datetime"
      assert file =~ "add :published_at, :naive_datetime"
      assert file =~ "add :edited_at, :utc_datetime"
    end
  end
end
