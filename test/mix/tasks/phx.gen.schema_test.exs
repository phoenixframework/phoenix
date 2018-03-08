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
      schema = Gen.Schema.build(~w(Blog.Post posts title:string), [])

      assert %Schema{
        alias: Post,
        module: Phoenix.Blog.Post,
        repo: Phoenix.Repo,
        migration?: true,
        migration_defaults: %{title: ""},
        plural: "posts",
        singular: "post",
        human_plural: "Posts",
        human_singular: "Post",
        attrs: [title: :string],
        types: %{title: :string},
        route_helper: "post",
        defaults: %{title: ""},
      } = schema
      assert String.ends_with?(schema.file, "lib/phoenix/blog/post.ex")
    end
  end

  test "build with nested web namespace", config do
    in_tmp_project config.test, fn ->
      schema = Gen.Schema.build(~w(Blog.Post posts title:string --web API.V1), [])

      assert %Schema{
        alias: Post,
        module: Phoenix.Blog.Post,
        repo: Phoenix.Repo,
        migration?: true,
        migration_defaults: %{title: ""},
        plural: "posts",
        singular: "post",
        human_plural: "Posts",
        human_singular: "Post",
        attrs: [title: :string],
        types: %{title: :string},
        route_helper: "api_v1_post",
        defaults: %{title: ""},
      } = schema
      assert String.ends_with?(schema.file, "lib/phoenix/blog/post.ex")
    end
  end

  test "table name missing from references", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/expect the table to be given to user_id:references/, fn ->
        Gen.Schema.run(~w(Blog.Post posts user_id:references))
      end
    end
  end

  test "type missing from array", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/expect the type of the array to be given to settings:array/, fn ->
        Gen.Schema.run(~w(Blog.Post posts settings:array))
      end
    end
  end

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Gen.Schema.run(~w(Blog Post title:string))
    end
  end

  test "plural can't have uppercased characters or camelized format" do
    assert_raise Mix.Error, fn ->
      Gen.Schema.run(~w(Blog Post Posts title:string))
    end

    assert_raise Mix.Error, fn ->
      Gen.Schema.run(~w(Blog Post BlogPosts title:string))
    end
  end

  test "table name omitted", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, fn ->
        Gen.Schema.run(~w(Blog.Post))
      end
    end
  end

  test "generates schema", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post blog_posts title:string))
      assert_file "lib/phoenix/blog/post.ex"

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_posts.exs")
      assert_file migration, fn file ->
        assert file =~ "create table(:blog_posts) do"
      end
    end
  end

  test "generates nested schema", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Admin.User users name:string))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users.exs")
      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreateUsers do"
        assert file =~ "create table(:users) do"
      end

      assert_file "lib/phoenix/blog/admin/user.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Admin.User do"
        assert file =~ "schema \"users\" do"
      end
    end
  end

  test "generates custom table name", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts --table cms_posts))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_cms_posts.exs")
      assert_file migration, fn file ->
        assert file =~ "create table(:cms_posts) do"
      end
    end
  end

  test "generates unique indices" , config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title:unique unique_int:integer:unique))
      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePosts do"
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

  test "generates references and belongs_to associations", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title user_id:references:users))
      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file migration, fn file ->
        assert file =~ "add :user_id, references(:users, on_delete: :nothing)"
        assert file =~ "create index(:posts, [:user_id])"
      end

      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "field :user_id, :id"
      end
    end
  end

  test "generates references with unique indexes", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title user_id:references:users unique_post_id:references:posts:unique))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePosts do"
        assert file =~ "create table(:posts) do"
        assert file =~ "add :user_id, references(:users, on_delete: :nothing)"
        assert file =~ "add :unique_post_id, references(:posts, on_delete: :nothing)"
        assert file =~ "create index(:posts, [:user_id])"
        assert file =~ "create unique_index(:posts, [:unique_post_id])"
      end

      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Post do"
        assert file =~ "field :user_id, :id"
        assert file =~ "field :unique_post_id, :id"
      end
    end
  end

  test "generates schema with proper datetime types", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Comment comments title:string drafted_at:datetime published_at:naive_datetime edited_at:utc_datetime))

      assert_file "lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :drafted_at, :naive_datetime"
        assert file =~ "field :published_at, :naive_datetime"
        assert file =~ "field :edited_at, :utc_datetime"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:comments)"
        assert file =~ "add :drafted_at, :naive_datetime"
        assert file =~ "add :published_at, :naive_datetime"
        assert file =~ "add :edited_at, :utc_datetime"
      end
    end
  end

  test "generates migration with binary_id", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title user_id:references:users --binary-id))

      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "field :user_id, :binary_id"
      end

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")
      assert_file migration, fn file ->
        assert file =~ "create table(:posts, primary_key: false) do"
        assert file =~ "add :id, :binary_id, primary_key: true"
        assert file =~ "add :user_id, references(:users, on_delete: :nothing, type: :binary_id)"
      end
    end
  end

  test "skips migration with --no-migration option", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts --no-migration))
      assert [] = Path.wildcard("priv/repo/migrations/*")
    end
  end

  test "uses defaults from :generators configuration" do
    in_tmp_project "uses defaults from generators configuration (migration)", fn ->
      with_generator_env [migration: false], fn ->
        Gen.Schema.run(~w(Blog.Post posts))

        assert [] = Path.wildcard("priv/repo/migrations/*")
      end
    end

    in_tmp_project "uses defaults from generators configuration (binary_id)", fn ->
      with_generator_env [binary_id: true], fn ->
        Gen.Schema.run(~w(Blog.Post posts))

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

        assert_file migration, fn file ->
          assert file =~ "create table(:posts, primary_key: false) do"
          assert file =~ "add :id, :binary_id, primary_key: true"
        end
      end
    end
  end

  describe "inside umbrella" do
    test "raises with false context_app", config do
      in_tmp_umbrella_project config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: false)

        assert_raise Mix.Error, ~r/no context_app configured/, fn ->
          Gen.Schema.run(~w(Blog.Post blog_posts title:string))
        end
      end
    end

    test "with context_app set to nil", config do
      in_tmp_umbrella_project config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: nil)

        Gen.Schema.run(~w(Blog.Post blog_posts title:string))

        assert_file "lib/phoenix/blog/post.ex"
        assert [_] = Path.wildcard("priv/repo/migrations/*_create_blog_posts.exs")
      end
    end

    test "with context_app", config do
      in_tmp_umbrella_project config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})

        Gen.Schema.run(~w(Blog.Post blog_posts title:string))

        assert_file "another_app/lib/another_app/blog/post.ex"
        assert [_] = Path.wildcard("another_app/priv/repo/migrations/*_create_blog_posts.exs")
      end
    end
  end
end
