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

  test "generates schema", config do
    in_tmp_project config.test, fn ->
      Gen.Schema.run(~w(Blog.Post posts title:string))
      assert_file "lib/phoenix/blog/post.ex"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")
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
