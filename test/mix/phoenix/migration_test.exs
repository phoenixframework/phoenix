defmodule Mix.Phoenix.MigrationTest do
  use ExUnit.Case, async: true

  alias Mix.Phoenix.{Migration, Schema, Attribute}

  test "module/0 returns migration module based on the Mix application" do
    assert Migration.module() == Ecto.Migration
    Application.put_env(:ecto_sql, :migration_module, Sample.App.Migration)
    assert Migration.module() == Sample.App.Migration
  after
    Application.delete_env(:ecto_sql, :migration_module)
  end

  test "table_options/1 returns possible table options" do
    assert Migration.table_options(%Schema{}) == ""
    assert Migration.table_options(%Schema{prefix: "some_prefix"}) == ", prefix: \"some_prefix\""
    assert Migration.table_options(%Schema{binary_id: true}) == ", primary_key: false"
    assert Migration.table_options(%Schema{opts: [primary_key: "uuid"]}) == ", primary_key: false"

    schema = %Schema{prefix: "some_prefix", binary_id: true, opts: [primary_key: "uuid"]}
    assert Migration.table_options(schema) == ", primary_key: false, prefix: \"some_prefix\""
  end

  test "maybe_specific_primary_key/1 returns specific primary key column by options " <>
         "`binary_id` or `primary_key`" do
    assert Migration.maybe_specific_primary_key(%Schema{}) == nil

    assert Migration.maybe_specific_primary_key(%Schema{binary_id: true}) ==
             "      add :id, :binary_id, primary_key: true\n"

    assert Migration.maybe_specific_primary_key(%Schema{opts: [primary_key: "uuid"]}) ==
             "      add :uuid, :id, primary_key: true\n"

    schema = %Schema{binary_id: true, opts: [primary_key: "uuid"]}

    assert Migration.maybe_specific_primary_key(schema) ==
             "      add :uuid, :binary_id, primary_key: true\n"
  end

  @parsed_attrs [
    %Attribute{name: :points, options: %{unique: true}, type: :integer},
    %Attribute{name: :price, options: %{precision: 10, scale: 5}, type: :decimal},
    %Attribute{
      name: :the_cake_is_a_lie,
      type: :boolean,
      options: %{default: true, required: true}
    },
    %Attribute{name: :title, type: :string, options: %{size: 40, index: true, required: true}},
    %Attribute{name: :card_number, type: :string, options: %{size: 16, redact: true}},
    %Attribute{name: :name, options: %{}, type: :text},
    %Attribute{
      name: :post_id,
      type: :references,
      options: %{
        required: true,
        index: true,
        association_name: :post,
        referenced_column: :id,
        referenced_type: :id,
        referenced_table: "posts",
        on_delete: :nothing,
        association_schema: TestApp.Blog.Post
      }
    },
    %Attribute{
      name: :booking_id,
      type: :references,
      options: %{
        index: true,
        unique: true,
        association_name: :reservation,
        referenced_column: :uuid,
        referenced_type: :binary_id,
        referenced_table: "bookings",
        on_delete: :nilify_all,
        association_schema: TestApp.Blog.Booking
      }
    },
    %Attribute{
      name: :book_id,
      type: :references,
      options: %{
        index: true,
        association_name: :book,
        referenced_column: :isbn,
        referenced_type: :string,
        referenced_table: "books",
        on_delete: {:nilify, [:book_id, :book_name]},
        association_schema: TestApp.Blog.Book
      }
    },
    %Attribute{name: :data, type: :any, options: %{virtual: true, unique: true}},
    %Attribute{name: :tags1, type: {:array, :string}, options: %{required: true}},
    %Attribute{name: :tags2, type: {:array, :integer}, options: %{}},
    %Attribute{
      name: :tags3,
      type: {:array, :enum},
      options: %{required: true, values: [:published, :unpublished]}
    },
    %Attribute{
      name: :tags4,
      type: {:array, :enum},
      options: %{values: [published: 1, unpublished: 2]}
    },
    %Attribute{name: :stages1, type: :enum, options: %{values: [:published, :unpublished]}},
    %Attribute{
      name: :stages2,
      type: :enum,
      options: %{required: true, values: [published: 1, unpublished: 2]}
    }
  ]

  test "columns_and_references/1 returns formatted columns and references" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Migration.columns_and_references(schema) ==
             """
                   add :card_number, :string, size: 16
                   add :name, :text
                   add :points, :integer
                   add :price, :decimal, precision: 10, scale: 5
                   add :stages1, :string
                   add :stages2, :integer, null: false
                   add :tags1, {:array, :string}, null: false
                   add :tags2, {:array, :integer}
                   add :tags3, {:array, :string}, null: false
                   add :tags4, {:array, :integer}
                   add :the_cake_is_a_lie, :boolean, default: true, null: false
                   add :title, :string, size: 40, null: false
                   add :book_id, references("books", column: :isbn, type: :string, on_delete: {:nilify, [:book_id, :book_name]})
                   add :booking_id, references("bookings", column: :uuid, type: :binary_id, on_delete: :nilify_all)
                   add :post_id, references("posts", on_delete: :nothing), null: false
             """
  end

  test "timestamps_type/1 returns type option for `timestamps` function" do
    schema = %Schema{timestamp_type: :naive_datetime}

    assert Migration.timestamps_type(schema) == ""

    schema = %Schema{timestamp_type: :utc_datetime}

    assert Migration.timestamps_type(schema) == "type: :utc_datetime"
  end

  describe "indexes/1" do
    test "returns formatted indexes" do
      schema = %Schema{table: "comments", attrs: @parsed_attrs}

      assert Migration.indexes(schema) ==
               """


                   create index("comments", [:points], unique: true)
                   create index("comments", [:title])
                   create index("comments", [:book_id])
                   create index("comments", [:booking_id], unique: true)
                   create index("comments", [:post_id])
               """
               |> String.trim_trailing("\n")
    end

    test "applies prefix option" do
      schema = %Schema{table: "comments", attrs: @parsed_attrs, prefix: "some_prefix"}

      assert Migration.indexes(schema) ==
               """


                   create index("comments", [:points], prefix: "some_prefix", unique: true)
                   create index("comments", [:title], prefix: "some_prefix")
                   create index("comments", [:book_id], prefix: "some_prefix")
                   create index("comments", [:booking_id], prefix: "some_prefix", unique: true)
                   create index("comments", [:post_id], prefix: "some_prefix")
               """
               |> String.trim_trailing("\n")
    end
  end
end
