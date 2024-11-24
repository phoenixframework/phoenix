defmodule Mix.Phoenix.MigrationTest do
  use ExUnit.Case, async: true

  alias Mix.Phoenix.{Migration, Schema, Attribute}

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
        type: :id,
        table: "posts",
        on_delete: :nothing,
        referenced_schema: TestApp.Blog.Post
      }
    },
    %Attribute{
      name: :booking_id,
      type: :references,
      options: %{
        index: true,
        unique: true,
        association_name: :reservation,
        column: :uuid,
        type: :binary_id,
        table: "bookings",
        on_delete: :nilify_all,
        referenced_schema: TestApp.Blog.Booking
      }
    },
    %Attribute{
      name: :book_id,
      type: :references,
      options: %{
        index: true,
        association_name: :book,
        column: :isbn,
        type: :string,
        table: "books",
        on_delete: {:nilify, [:book_id, :book_name]},
        referenced_schema: TestApp.Blog.Book
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

  test "module/0 returns migration module to use in migration based on the Mix application" do
    assert Migration.module() == Ecto.Migration
    Application.put_env(:ecto_sql, :migration_module, Sample.App.Migration)
    assert Migration.module() == Sample.App.Migration
  after
    Application.delete_env(:ecto_sql, :migration_module)
  end

  test "columns_and_references/1 returns formatted columns and references to list in migration" do
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

  test "indexes/1 returns formatted indexes to list in migration" do
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
end
