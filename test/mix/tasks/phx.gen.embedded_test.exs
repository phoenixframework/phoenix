Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.EmbeddedTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen
  alias Mix.Phoenix.Schema

  setup do
    Mix.Task.clear()
    :ok
  end

  test "build" do
    in_tmp_project "embedded build", fn ->
      schema = Gen.Embedded.build(~w(Blog.Post title:string))

      assert %Schema{
        alias: Post,
        module: Phoenix.Blog.Post,
        repo: Phoenix.Repo,
        migration?: false,
        migration_defaults: %{title: ""},
        plural: nil,
        singular: "post",
        human_plural: "Nil",
        human_singular: "Post",
        attrs: [title: :string],
        types: %{title: :string},
        embedded?: true,
        defaults: %{title: ""},
      } = schema
      assert String.ends_with?(schema.file, "lib/phoenix/blog/post.ex")
    end
  end

  test "generates embedded schema", config do
    in_tmp_project config.test, fn ->
      Gen.Embedded.run(~w(Blog.Post title:string))
      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "embedded_schema do"
      end
    end
  end

  test "generates nested embedded schema", config do
    in_tmp_project config.test, fn ->
      Gen.Embedded.run(~w(Blog.Admin.User name:string))

      assert_file "lib/phoenix/blog/admin/user.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Admin.User do"
        assert file =~ "embedded_schema do"
      end
    end
  end

  test "generates embedded schema with proper datetime types", config do
    in_tmp_project config.test, fn ->
      Gen.Embedded.run(~w(Blog.Comment title:string drafted_at:datetime published_at:naive_datetime edited_at:utc_datetime))

      assert_file "lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :drafted_at, :naive_datetime"
        assert file =~ "field :published_at, :naive_datetime"
        assert file =~ "field :edited_at, :utc_datetime"
      end
    end
  end
end
