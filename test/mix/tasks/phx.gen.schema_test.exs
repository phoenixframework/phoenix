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
    in_tmp "build", fn ->
      schema = Gen.Schema.build(~w(Blog.Post posts title:string))

      assert %Schema{
        alias: Post,
        module: Phoenix.Blog.Post,
        repo: Phoenix.Repo,
        file: "lib/blog/post.ex",
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

  test "plural can't contain a colon" do
    assert_raise Mix.Error, fn ->
      Gen.Schema.run ~w(Admin.User name:string foo:string)
    end
  end

  test "plural can't have uppercased characters or camelized format" do
    assert_raise Mix.Error, fn ->
      Gen.Schema.run ~w(Admin.User Users foo:string)
    end

    assert_raise Mix.Error, fn ->
      Gen.Schema.run ~w(Admin.User AdminUsers foo:string)
    end
  end

  test "name is already defined" do
    assert_raise Mix.Error, fn ->
      Gen.Schema.run ~w(DupSchema schemas)
    end
  end

  test "generates schema" do
    in_tmp "generates schema", fn ->
      Gen.Schema.run(~w(Blog.Post posts title:string))

      assert_file "lib/blog/post.ex"
      assert [_] = Path.wildcard("priv/repo/migrations/*_create_post.exs")
    end
  end
end
