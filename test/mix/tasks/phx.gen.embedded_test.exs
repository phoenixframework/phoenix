Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.Gen.EmbeddedTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen
  alias Mix.Phoenix.{Schema, Attribute}

  setup do
    Mix.Task.clear()
    :ok
  end

  test "build" do
    in_tmp_project("embedded build", fn ->
      # Accepts first attribute to be required.
      send(self(), {:mix_shell_input, :yes?, true})
      schema = Gen.Embedded.build(~w(Blog.Post title:string))

      assert %Schema{
               alias: Post,
               module: Phoenix.Blog.Post,
               repo: Phoenix.Repo,
               plural: nil,
               singular: "post",
               human_plural: "Nil",
               human_singular: "Post",
               attrs: [%Attribute{name: :title, type: :string, options: %{required: true}}],
               migration?: false,
               embedded?: true
             } = schema

      assert String.ends_with?(schema.file, "lib/phoenix/blog/post.ex")
    end)
  end

  test "generates embedded schema", config do
    in_tmp_project(config.test, fn ->
      Gen.Embedded.run(~w(Blog.Post))

      assert_file("lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "embedded_schema do"
      end)
    end)
  end

  test "generates nested embedded schema", config do
    in_tmp_project(config.test, fn ->
      Gen.Embedded.run(~w(Blog.Admin.User))

      assert_file("lib/phoenix/blog/admin/user.ex", fn file ->
        assert file =~ "defmodule Phoenix.Blog.Admin.User do"
        assert file =~ "embedded_schema do"
      end)
    end)
  end

  test "generates embedded schema with proper datetime types", config do
    in_tmp_project(config.test, fn ->
      Gen.Embedded.run(
        ~w(Blog.Comment title:string:* drafted_at:datetime published_at:naive_datetime edited_at:utc_datetime)
      )

      assert_file("lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :drafted_at, :naive_datetime"
        assert file =~ "field :published_at, :naive_datetime"
        assert file =~ "field :edited_at, :utc_datetime"
      end)
    end)
  end

  test "generates embedded schema with enum", config do
    in_tmp_project(config.test, fn ->
      Gen.Embedded.run(~w(Blog.Comment title status:enum:[unpublished,published,deleted]:*))

      assert_file("lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :status, Ecto.Enum, values: [:unpublished, :published, :deleted]"
      end)
    end)
  end

  test "generates embedded schema with redact option", config do
    in_tmp_project(config.test, fn ->
      Gen.Embedded.run(~w(Blog.Comment title secret:string:*:redact))

      assert_file("lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :secret, :string, redact: true"
      end)
    end)
  end

  test "generates embedded schema with references", config do
    in_tmp_project(config.test, fn ->
      Gen.Embedded.run(
        ~w(Blog.Comment body word_count:integer author_id:references:*:table,users:column,id:type,string)
      )

      assert_file("lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :body, :string"
        assert file =~ "field :word_count, :integer"
        assert file =~ "belongs_to :author, Phoenix.Blog.Author, type: :string"
      end)
    end)
  end
end
