defmodule Mix.Phoenix.SchemaTest do
  use ExUnit.Case, async: true

  alias Mix.Phoenix.{Schema, Attribute}

  test "valid?/1 validates format of schema name" do
    refute Schema.valid?("name")
    assert Schema.valid?("Name")
    refute Schema.valid?("7Name")
    assert Schema.valid?("Name7")
    assert Schema.valid?("N7")
    refute Schema.valid?("some.Name")
    refute Schema.valid?("Some.name")
    assert Schema.valid?("Some.Name")
    refute Schema.valid?("Some00.7Name")
    assert Schema.valid?("Some00.Name7")
    refute Schema.valid?("Nested.context.with.Schema.Name")
    assert Schema.valid?("Nested.Context.With.Schema.Name")
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

  test "fields_and_associations/1 returns formatted columns and references to list in migration" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Schema.fields_and_associations(schema) ==
             """

                 field :card_number, :string, redact: true
                 field :data, :any, virtual: true
                 field :name, :string
                 field :points, :integer
                 field :price, :decimal
                 field :stages1, Ecto.Enum, values: [:published, :unpublished]
                 field :stages2, Ecto.Enum, values: [published: 1, unpublished: 2]
                 field :tags1, {:array, :string}
                 field :tags2, {:array, :integer}
                 field :tags3, {:array, Ecto.Enum}, values: [:published, :unpublished]
                 field :tags4, {:array, Ecto.Enum}, values: [published: 1, unpublished: 2]
                 field :the_cake_is_a_lie, :boolean, default: true
                 field :title, :string
                 belongs_to :book, TestApp.Blog.Book, references: :isbn, type: :string
                 belongs_to :reservation, TestApp.Blog.Booking, foreign_key: :booking_id, references: :uuid, type: :binary_id
                 belongs_to :post, TestApp.Blog.Post
             """

    schema = %Schema{attrs: @parsed_attrs, binary_id: true}

    assert Schema.fields_and_associations(schema) ==
             """

                 field :card_number, :string, redact: true
                 field :data, :any, virtual: true
                 field :name, :string
                 field :points, :integer
                 field :price, :decimal
                 field :stages1, Ecto.Enum, values: [:published, :unpublished]
                 field :stages2, Ecto.Enum, values: [published: 1, unpublished: 2]
                 field :tags1, {:array, :string}
                 field :tags2, {:array, :integer}
                 field :tags3, {:array, Ecto.Enum}, values: [:published, :unpublished]
                 field :tags4, {:array, Ecto.Enum}, values: [published: 1, unpublished: 2]
                 field :the_cake_is_a_lie, :boolean, default: true
                 field :title, :string
                 belongs_to :book, TestApp.Blog.Book, references: :isbn, type: :string
                 belongs_to :reservation, TestApp.Blog.Booking, foreign_key: :booking_id, references: :uuid
                 belongs_to :post, TestApp.Blog.Post, type: :id
             """
  end

  test "timestamps_type/1 returns type option for `timestamps` function" do
    schema = %Schema{timestamp_type: :naive_datetime}

    assert Schema.timestamps_type(schema) == ""

    schema = %Schema{timestamp_type: :utc_datetime}

    assert Schema.timestamps_type(schema) == "type: :utc_datetime"
  end

  test "cast_fields/1 returns formatted fields to cast in schema" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Schema.cast_fields(schema) ==
             ":card_number, " <>
               ":data, " <>
               ":name, " <>
               ":points, " <>
               ":price, " <>
               ":stages1, " <>
               ":stages2, " <>
               ":tags1, " <>
               ":tags2, " <>
               ":tags3, " <>
               ":tags4, " <>
               ":the_cake_is_a_lie, " <>
               ":title, " <>
               ":book_id, " <>
               ":booking_id, " <>
               ":post_id"
  end

  test "required_fields/1 returns formatted fields to require in schema" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Schema.required_fields(schema) ==
             ":stages2, :tags1, :tags3, :the_cake_is_a_lie, :title, :post_id"
  end

  test "changeset_constraints/1 returns specific changeset constraints to list in schema" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Schema.changeset_constraints(schema) ==
             """

                 |> validate_length(:card_number, max: 16)
                 |> validate_length(:title, max: 40)
                 |> assoc_constraint(:book)
                 |> assoc_constraint(:post)
                 |> assoc_constraint(:reservation)
                 |> unique_constraint(:points)
                 |> unique_constraint(:booking_id)
             """
             |> String.trim_trailing("\n")
  end

  test "length_validations/1 returns length validations to list in schema" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Schema.length_validations(schema) ==
             """

                 |> validate_length(:card_number, max: 16)
                 |> validate_length(:title, max: 40)
             """
             |> String.trim_trailing("\n")
  end

  test "assoc_constraints/1 returns association constraints to list in schema" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Schema.assoc_constraints(schema) ==
             """

                 |> assoc_constraint(:book)
                 |> assoc_constraint(:post)
                 |> assoc_constraint(:reservation)
             """
             |> String.trim_trailing("\n")
  end

  test "unique_constraints/1 returns unique constraints to list in schema" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Schema.unique_constraints(schema) ==
             """

                 |> unique_constraint(:points)
                 |> unique_constraint(:booking_id)
             """
             |> String.trim_trailing("\n")
  end
end
