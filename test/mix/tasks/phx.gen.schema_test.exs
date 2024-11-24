Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.Gen.SchemaTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen
  alias Mix.Phoenix.{Schema, Attribute}

  setup do
    Mix.Task.clear()
    :ok
  end

  test "build" do
    in_tmp_project("build", fn ->
      schema = Gen.Schema.build(~w(Blog.Post posts title:string:* content:text tags:map), [])

      assert %Schema{
               alias: Post,
               module: Phoenix.Blog.Post,
               repo: Phoenix.Repo,
               migration?: true,
               plural: "posts",
               singular: "post",
               human_plural: "Posts",
               human_singular: "Post",
               attrs: [
                 %Attribute{name: :title, type: :string, options: %{required: true}},
                 %Attribute{name: :content, type: :text, options: %{}},
                 %Attribute{name: :tags, type: :map, options: %{}}
               ],
               route_helper: "post"
             } = schema

      assert String.ends_with?(schema.file, "lib/phoenix/blog/post.ex")
    end)
  end

  test "build with nested web namespace", config do
    in_tmp_project(config.test, fn ->
      schema = Gen.Schema.build(~w(Blog.Post posts title:string:* --web API.V1), [])

      assert %Schema{
               alias: Post,
               module: Phoenix.Blog.Post,
               repo: Phoenix.Repo,
               migration?: true,
               plural: "posts",
               singular: "post",
               human_plural: "Posts",
               human_singular: "Post",
               attrs: [%Attribute{name: :title, type: :string, options: %{}}],
               route_helper: "api_v1_post"
             } = schema

      assert String.ends_with?(schema.file, "lib/phoenix/blog/post.ex")
    end)
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
    in_tmp_project(config.test, fn ->
      assert_raise Mix.Error, fn ->
        Gen.Schema.run(~w(Blog.Post))
      end
    end)
  end

  test "generates schema", config do
    in_tmp_project(config.test, fn ->
      Gen.Schema.run(~w(Blog.Post blog_posts))

      assert_file("lib/phoenix/blog/post.ex")

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_blog_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "create table(\"blog_posts\") do"
      end)
    end)
  end

  test "allows a custom repo", config do
    in_tmp_project(config.test, fn ->
      Gen.Schema.run(~w(Blog.Post blog_posts --repo MyApp.CustomRepo))

      assert [migration] = Path.wildcard("priv/custom_repo/migrations/*_create_blog_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "defmodule MyApp.CustomRepo.Migrations.CreateBlogPosts do"
      end)
    end)
  end

  test "allows a custom migration dir", config do
    in_tmp_project(config.test, fn ->
      Gen.Schema.run(~w(Blog.Post blog_posts --migration-dir priv/custom_dir))

      assert [migration] = Path.wildcard("priv/custom_dir/*_create_blog_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreateBlogPosts do"
      end)
    end)
  end

  test "custom migration_dir takes precedence over custom repo name", config do
    in_tmp_project(config.test, fn ->
      Gen.Schema.run(
        ~w(Blog.Post blog_posts --repo MyApp.CustomRepo --migration-dir priv/custom_dir)
      )

      assert [migration] = Path.wildcard("priv/custom_dir/*_create_blog_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "defmodule MyApp.CustomRepo.Migrations.CreateBlogPosts do"
      end)
    end)
  end

  test "adds validation for required fields", config do
    in_tmp_project(config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title:string:* tags:map:* published_at:naive_datetime))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePosts do"
        assert file =~ "create table(\"posts\") do"
        assert file =~ "add :title, :string, null: false"
        assert file =~ "add :tags, :map, null: false"
        assert file =~ "add :published_at, :naive_datetime"
      end)

      assert_file("lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "cast(attrs, [:published_at, :tags, :title]"
        assert file =~ "validate_required([:tags, :title]"
      end)
    end)
  end

  test "generates nested schema", config do
    in_tmp_project(config.test, fn ->
      Gen.Schema.run(~w(Blog.Admin.User users))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_users.exs")

      assert_file(migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreateUsers do"
        assert file =~ "create table(\"users\") do"
      end)

      assert_file("lib/phoenix/blog/admin/user.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Admin.User do"
        assert file =~ "schema \"users\" do"
      end)
    end)
  end

  test "generates custom table name", config do
    in_tmp_project(config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts --table cms_posts))

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_cms_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "create table(\"cms_posts\") do"
      end)
    end)
  end

  test "generates unique indices", config do
    in_tmp_project(config.test, fn ->
      send(self(), {:mix_shell_input, :yes?, true})

      Gen.Schema.run(
        ~w(Blog.Post posts title:string:unique secret:string:redact unique_int:integer:unique)
      )

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePosts do"
        assert file =~ "create table(\"posts\") do"
        assert file =~ "add :title, :string"
        assert file =~ "add :unique_int, :integer"
        assert file =~ "add :secret, :string"
        assert file =~ "create index(\"posts\", [:title], unique: true)"
        assert file =~ "create index(\"posts\", [:unique_int], unique: true)"
      end)

      assert_file("lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Post do"
        assert file =~ "schema \"posts\" do"
        assert file =~ "field :title, :string"
        assert file =~ "field :unique_int, :integer"
        assert file =~ "field :secret, :string, redact: true"
      end)
    end)
  end

  test "generates references and belongs_to associations", config do
    in_tmp_project(config.test, fn ->
      send(self(), {:mix_shell_input, :yes?, true})
      Gen.Schema.run(~w(Blog.Post posts title user_id:references:table,users:type,id))
      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "add :user_id, references(\"users\", on_delete: :nothing)"
        assert file =~ "create index(\"posts\", [:user_id])"
      end)

      assert_file("lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "belongs_to :user, Phoenix.Blog.User"
      end)
    end)
  end

  test "generates references with unique indexes", config do
    in_tmp_project(config.test, fn ->
      send(self(), {:mix_shell_input, :yes?, true})

      Gen.Schema.run(
        ~w(Blog.Post posts title user_id:references:table,users:type,binary_id:assoc,author unique_category_id:references:table,categories:type,id:Catalog.Category:unique)
      )

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "defmodule Phoenix.Repo.Migrations.CreatePosts do"
        assert file =~ "create table(\"posts\") do"

        assert file =~
                 "add :user_id, references(\"users\", type: :binary_id, on_delete: :nothing)"

        assert file =~ "add :unique_category_id, references(\"categories\", on_delete: :nothing)"
        assert file =~ "create index(\"posts\", [:user_id])"
        assert file =~ "create index(\"posts\", [:unique_category_id], unique: true)"
      end)

      assert_file("lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Post do"
        assert file =~ "belongs_to :unique_category, Phoenix.Catalog.Category"

        assert file =~
                 "belongs_to :author, Phoenix.Blog.User, foreign_key: :user_id, type: :binary_id"
      end)
    end)
  end

  test "generates schema with proper datetime types", config do
    in_tmp_project(config.test, fn ->
      send(self(), {:mix_shell_input, :yes?, true})

      Gen.Schema.run(
        ~w(Blog.Comment comments title:string drafted_at:datetime published_at:naive_datetime edited_at:utc_datetime locked_at:naive_datetime_usec)
      )

      assert_file("lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :drafted_at, :naive_datetime"
        assert file =~ "field :published_at, :naive_datetime"
        assert file =~ "field :locked_at, :naive_datetime_usec"
        assert file =~ "field :edited_at, :utc_datetime"
      end)

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")

      assert_file(path, fn file ->
        assert file =~ "create table(\"comments\")"
        assert file =~ "add :drafted_at, :naive_datetime"
        assert file =~ "add :published_at, :naive_datetime"
        assert file =~ "add :edited_at, :utc_datetime"
      end)
    end)
  end

  test "generates schema with enum", config do
    in_tmp_project(config.test, fn ->
      send(self(), {:mix_shell_input, :yes?, true})

      Gen.Schema.run(
        ~w(Blog.Comment comments title:string status:enum:[unpublished,published,deleted])
      )

      assert_file("lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :status, Ecto.Enum, values: [:unpublished, :published, :deleted]"
      end)

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_comments.exs")

      assert_file(path, fn file ->
        assert file =~ "create table(\"comments\")"
        assert file =~ "add :status, :string"
      end)
    end)
  end

  test "generates migration with binary_id", config do
    in_tmp_project(config.test, fn ->
      send(self(), {:mix_shell_input, :yes?, true})

      Gen.Schema.run(
        ~w(Blog.Post posts title user_id:references:table,users:type,binary_id --binary-id)
      )

      assert_file("lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "@primary_key {:id, :binary_id, autogenerate: true}"
        assert file =~ "@foreign_key_type :binary_id"
        assert file =~ "field :title, :string"
        assert file =~ "belongs_to :user, Phoenix.Blog.User"
      end)

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "create table(\"posts\", primary_key: false) do"
        assert file =~ "add :id, :binary_id, primary_key: true"
        assert file =~ "add :title, :string, null: false"

        assert file =~
                 "add :user_id, references(\"users\", type: :binary_id, on_delete: :nothing)"
      end)
    end)
  end

  test "generates schema and migration with prefix", config do
    in_tmp_project(config.test, fn ->
      send(self(), {:mix_shell_input, :yes?, true})
      Gen.Schema.run(~w(Blog.Post posts title --prefix cms))

      assert_file("lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "@schema_prefix :cms"
      end)

      assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

      assert_file(migration, fn file ->
        assert file =~ "create table(\"posts\", prefix: :cms) do"
      end)
    end)
  end

  test "skips migration with --no-migration option", config do
    in_tmp_project(config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts --no-migration))
      assert [] = Path.wildcard("priv/repo/migrations/*")
    end)
  end

  test "uses defaults from :generators configuration" do
    in_tmp_project("uses defaults from generators configuration (migration)", fn ->
      with_generator_env([migration: false], fn ->
        Gen.Schema.run(~w(Blog.Post posts))

        assert [] = Path.wildcard("priv/repo/migrations/*")
      end)
    end)

    in_tmp_project("uses defaults from generators configuration (binary_id)", fn ->
      with_generator_env([binary_id: true], fn ->
        send(self(), {:mix_shell_input, :yes?, true})
        Gen.Schema.run(~w(Blog.Post posts title user_id:references:table,users:type,id))

        assert_file("lib/phoenix/blog/post.ex", fn file ->
          assert file =~ "@primary_key {:id, :binary_id, autogenerate: true}"
          assert file =~ "@foreign_key_type :binary_id"
          assert file =~ "field :title, :string"
          assert file =~ "belongs_to :user, Phoenix.Blog.User, type: :id"
        end)

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

        assert_file(migration, fn file ->
          assert file =~ "create table(\"posts\", primary_key: false) do"
          assert file =~ "add :id, :binary_id, primary_key: true"
          assert file =~ "add :title, :string, null: false"
          assert file =~ "add :user_id, references(\"users\", on_delete: :nothing)"
        end)
      end)
    end)

    in_tmp_project("uses defaults from generators configuration (:utc_datetime)", fn ->
      with_generator_env([timestamp_type: :utc_datetime], fn ->
        Gen.Schema.run(~w(Blog.Post posts))

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

        assert_file(migration, fn file ->
          assert file =~ "timestamps(type: :utc_datetime)"
        end)

        assert_file("lib/phoenix/blog/post.ex", fn file ->
          assert file =~ "timestamps(type: :utc_datetime)"
        end)
      end)
    end)
  end

  test "generates migrations with a custom migration module", config do
    in_tmp_project(config.test, fn ->
      try do
        Application.put_env(:ecto_sql, :migration_module, MyCustomApp.MigrationModule)

        Gen.Schema.run(~w(Blog.Post posts))

        assert [migration] = Path.wildcard("priv/repo/migrations/*_create_posts.exs")

        assert_file(migration, fn file ->
          assert file =~ "use MyCustomApp.MigrationModule"
          assert file =~ "create table(\"posts\") do"
        end)
      after
        Application.delete_env(:ecto_sql, :migration_module)
      end
    end)
  end

  test "generates schema without extra line break", config do
    in_tmp_project(config.test, fn ->
      send(self(), {:mix_shell_input, :yes?, true})
      Gen.Schema.run(~w(Blog.Post posts title))

      assert_file("lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "import Ecto.Changeset\n\n  schema"
      end)
    end)
  end

  describe "inside umbrella" do
    test "raises with false context_app", config do
      in_tmp_umbrella_project(config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: false)

        assert_raise Mix.Error, ~r/no context_app configured/, fn ->
          send(self(), {:mix_shell_input, :yes?, true})
          Gen.Schema.run(~w(Blog.Post blog_posts title:string))
        end
      end)
    end

    test "with context_app set to nil", config do
      in_tmp_umbrella_project(config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: nil)

        send(self(), {:mix_shell_input, :yes?, true})
        Gen.Schema.run(~w(Blog.Post blog_posts title:string))

        assert_file("lib/phoenix/blog/post.ex")
        assert [_] = Path.wildcard("priv/repo/migrations/*_create_blog_posts.exs")
      end)
    end

    test "with context_app", config do
      in_tmp_umbrella_project(config.test, fn ->
        Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})

        send(self(), {:mix_shell_input, :yes?, true})
        Gen.Schema.run(~w(Blog.Post blog_posts title:string))

        assert_file("another_app/lib/another_app/blog/post.ex")
        assert [_] = Path.wildcard("another_app/priv/repo/migrations/*_create_blog_posts.exs")
      end)
    end
  end
end
