defmodule Mix.Phoenix.AttributeTest do
  use ExUnit.Case, async: true

  alias Mix.Phoenix.Attribute

  describe "parse/2" do
    def parse_cli_attrs(cli_attrs),
      do: Attribute.parse(cli_attrs, {TestApp.Blog.Comment, TestApp})

    test "parses CLI attribute string into %Attribute{} struct, " <>
           "performs attribute's type and options validation, " <>
           "prefills some mandatory and default data to options map" do
      cli_attrs = [
        "points:integer:unique",
        "points:integer:default,0",
        "current_guess:integer:unique:virtual",
        "sum:float",
        "sum:float:default,0.0",
        "price:decimal",
        "price:decimal:precision,5:scale,2:unique",
        "price:decimal:precision,5",
        "price:decimal:default,0.0",
        "agreed:boolean",
        "the_cake_is_a_lie:boolean:default,true",
        "title",
        "title:string",
        "title:string:unique",
        "title:string:index",
        "title:string:required",
        "title:string:*:size,40",
        "card_number:string:redact",
        "name:text",
        "data:binary",
        "token:uuid",
        "date_of_birth:date",
        "happy_hour:time",
        "happy_hour:time_usec",
        "joined:naive_datetime",
        "joined:naive_datetime_usec",
        "joined:utc_datetime",
        "joined:utc_datetime_usec",
        "meta:map",
        "status:enum:[published,unpublished]",
        "status:enum:[[published,1],[unpublished,2]]",
        "post_id:references:table,posts:type,id",
        "author_id:references:table,users:type,binary_id:Accounts.Admin.User:on_delete,delete_all",
        "booking_id:references:table,bookings:type,id:assoc,reservation:unique",
        "book_id:references:table,books:type,string:column,isbn:on_delete,nilify[book_id,book_name]",
        "data:any:virtual",
        "joined:datetime",
        "tags:array",
        "tags:[array,string]",
        "tags:[array,integer]",
        "tags:[array,enum]:[published,unpublished]",
        "tags:[array,enum]:[[published,1],[unpublished,2]]"
      ]

      assert parse_cli_attrs(cli_attrs) == [
               %Attribute{name: :points, options: %{unique: true}, type: :integer},
               %Attribute{name: :points, options: %{default: 0}, type: :integer},
               %Attribute{
                 name: :current_guess,
                 options: %{virtual: true, unique: true},
                 type: :integer
               },
               %Attribute{name: :sum, options: %{}, type: :float},
               %Attribute{name: :sum, options: %{default: 0.0}, type: :float},
               %Attribute{name: :price, options: %{}, type: :decimal},
               %Attribute{
                 name: :price,
                 options: %{precision: 5, scale: 2, unique: true},
                 type: :decimal
               },
               %Attribute{name: :price, type: :decimal, options: %{precision: 5}},
               %Attribute{name: :price, type: :decimal, options: %{default: "0.0"}},
               %Attribute{
                 name: :agreed,
                 type: :boolean,
                 options: %{default: false, required: true}
               },
               %Attribute{
                 name: :the_cake_is_a_lie,
                 type: :boolean,
                 options: %{default: true, required: true}
               },
               %Attribute{name: :title, type: :string, options: %{}},
               %Attribute{name: :title, type: :string, options: %{}},
               %Attribute{name: :title, type: :string, options: %{unique: true}},
               %Attribute{name: :title, type: :string, options: %{index: true}},
               %Attribute{name: :title, type: :string, options: %{required: true}},
               %Attribute{name: :title, type: :string, options: %{required: true, size: 40}},
               %Attribute{name: :card_number, type: :string, options: %{redact: true}},
               %Attribute{name: :name, options: %{}, type: :text},
               %Attribute{name: :data, type: :binary, options: %{}},
               %Attribute{name: :token, type: :uuid, options: %{}},
               %Attribute{name: :date_of_birth, options: %{}, type: :date},
               %Attribute{name: :happy_hour, options: %{}, type: :time},
               %Attribute{name: :happy_hour, type: :time_usec, options: %{}},
               %Attribute{name: :joined, options: %{}, type: :naive_datetime},
               %Attribute{name: :joined, options: %{}, type: :naive_datetime_usec},
               %Attribute{name: :joined, type: :utc_datetime, options: %{}},
               %Attribute{name: :joined, type: :utc_datetime_usec, options: %{}},
               %Attribute{name: :meta, type: :map, options: %{}},
               %Attribute{
                 name: :status,
                 type: :enum,
                 options: %{values: [:published, :unpublished]}
               },
               %Attribute{
                 name: :status,
                 type: :enum,
                 options: %{values: [published: 1, unpublished: 2]}
               },
               %Attribute{
                 name: :post_id,
                 type: :references,
                 options: %{
                   index: true,
                   association_name: :post,
                   type: :id,
                   table: "posts",
                   on_delete: :nothing,
                   referenced_schema: TestApp.Blog.Post
                 }
               },
               %Attribute{
                 name: :author_id,
                 type: :references,
                 options: %{
                   index: true,
                   association_name: :author,
                   type: :binary_id,
                   table: "users",
                   on_delete: :delete_all,
                   referenced_schema: TestApp.Accounts.Admin.User
                 }
               },
               %Attribute{
                 name: :booking_id,
                 type: :references,
                 options: %{
                   index: true,
                   unique: true,
                   association_name: :reservation,
                   type: :id,
                   table: "bookings",
                   on_delete: :nothing,
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
               %Attribute{name: :data, type: :any, options: %{virtual: true}},
               %Attribute{name: :joined, type: :naive_datetime, options: %{}},
               %Attribute{name: :tags, type: {:array, :string}, options: %{}},
               %Attribute{name: :tags, type: {:array, :string}, options: %{}},
               %Attribute{name: :tags, type: {:array, :integer}, options: %{}},
               %Attribute{
                 name: :tags,
                 type: {:array, :enum},
                 options: %{values: [:published, :unpublished]}
               },
               %Attribute{
                 name: :tags,
                 type: {:array, :enum},
                 options: %{values: [published: 1, unpublished: 2]}
               }
             ]
    end

    test "raises with an unknown type, providing list of supported types" do
      assert_raise(
        Mix.Error,
        ~r"Unknown type `other` is given in CLI attribute `some:other`",
        fn -> parse_cli_attrs(["some:other"]) end
      )

      assert_raise(
        Mix.Error,
        ~r"Supported attribute types",
        fn -> parse_cli_attrs(["some:other"]) end
      )
    end

    test "raises with an unknown option, providing list of supported options for the type" do
      assert_raise(
        Mix.Error,
        ~r"Unknown option `other` is given in CLI attribute `title:string:other`",
        fn -> parse_cli_attrs(["title:string:other"]) end
      )

      assert_raise(
        Mix.Error,
        ~r"`string` supports following options",
        fn -> parse_cli_attrs(["title:string:other"]) end
      )
    end

    test "raises with a type specific issue, providing list of supported options for the type" do
      assert_raise(
        Mix.Error,
        ~r"CLI attribute `data:any` has issue related to its type `any`",
        fn -> parse_cli_attrs(["data:any"]) end
      )

      assert_raise(
        Mix.Error,
        ~r"CLI attribute `city:string:size,0` has issue related to its type `string`",
        fn -> parse_cli_attrs(["city:string:size,0"]) end
      )

      assert_raise(
        Mix.Error,
        ~r"CLI attribute `price:decimal:scale,1` has issue related to its type `decimal`",
        fn -> parse_cli_attrs(["price:decimal:scale,1"]) end
      )

      assert_raise(
        Mix.Error,
        ~r"CLI attribute `price:decimal:precision,10:scale,10` has issue related to its type `decimal`",
        fn -> parse_cli_attrs(["price:decimal:precision,10:scale,10"]) end
      )

      assert_raise(
        Mix.Error,
        ~r"CLI attribute `status:enum` has issue related to its type `enum`",
        fn -> parse_cli_attrs(["status:enum"]) end
      )

      assert_raise(
        Mix.Error,
        ~r"CLI attribute `status:\[array,enum\]` has issue related to its type `enum`",
        fn -> parse_cli_attrs(["status:[array,enum]"]) end
      )

      assert_raise(
        Mix.Error,
        ~r"`enum` supports following options",
        fn -> parse_cli_attrs(["status:[array,enum]"]) end
      )
    end

    test "notifies about first attribute will be marked as required " <>
           "if none of the given attributes are set to be required" do
      send(self(), {:mix_shell_input, :yes?, true})
      parse_cli_attrs(["body:text:index", "number_of_words:integer"])

      assert_received {:mix_shell, :info,
                       ["At least one attribute has to be specified as required." <> notice]}

      assert notice =~ "Hence first attribute `body:text:index` is going to be required."

      assert_received {:mix_shell, :yes?, [question]}
      assert question =~ "Proceed with chosen required attribute?"
    end
  end

  test "supported_types/0 lists supported attribute types with details and examples" do
    assert Attribute.supported_types() ==
             """
             ### Supported attribute types

               * `[array,inner_type]` - Composite type, requires `inner_type`, which cannot be `references`.
                     Examples:

                         tags:[array,string]
                         tags:[array,integer]
                         tags:[array,enum]:[published,unpublished]
                         tags:[array,enum]:[[published,1],[unpublished,2]]

               * `any` - Can be used only with option `virtual`.
                     Examples:

                         data:any:virtual

               * `array` - An alias for `[array,string]`.
                     Examples:

                         tags:array

               * `binary`

               * `boolean` - Default to `false`, which can be changed with option.
                     Examples:

                         agreed:boolean
                         the_cake_is_a_lie:boolean:default,true

               * `date`

               * `datetime` - An alias for `naive_datetime`.

               * `decimal` - Have specific options `precision` and `scale`.
                     Examples:

                         price:decimal
                         price:decimal:precision,5:scale,2
                         price:decimal:precision,5
                         price:decimal:default,0.0

               * `enum` - Requires at least one value in options. Values are translated into list or keyword list.
                     Examples:

                         status:enum:[published,unpublished]
                         status:enum:[[published,1],[unpublished,2]]
                         tags:[array,enum]:[published,unpublished]
                         tags:[array,enum]:[[published,1],[unpublished,2]]

               * `float`
                     Examples:

                         sum:float
                         sum:float:default,0.0

               * `integer`
                     Examples:

                         points:integer
                         points:integer:default,0

               * `map`

               * `naive_datetime`

               * `naive_datetime_usec`

               * `references` - All info is inferred from the attribute name unless customized via options. Referenced schema is inferred in scope of the given context. Different schema can be provided in full form `Context.Schema` in options. Referenced schema should exist in the app.
                     Examples:

                         post_id:references
                         author_id:references:Accounts.User

               * `string` - Default type. Can be omitted if no options are provided. Use `size` option to limit number of characters.
                     Examples:

                         title
                         title:string
                         title:string:size,40:unique

               * `text`

               * `time`

               * `time_usec`

               * `utc_datetime`

               * `utc_datetime_usec`

               * `uuid`
             """
  end

  test "supported_options/0 lists supported attribute options with details and examples" do
    assert Attribute.supported_options() ==
             """
             ### Supported attribute options

               * `*` - An alias for `required`.
                     Examples:

                         title:string:*

               * `Context.Schema` - Referenced schema name for `references`. For cases when schema cannot be inferred from the attribute name, or context differs.
                     Examples:

                         author_id:references:Accounts.User

               * `[[one,1],[two,2]]` - Keyword list of values for `enum` type. At least one value is mandatory.
                     Examples:

                         status:enum:[[published,1],[unpublished,2]]

               * `[one,two]` - List of values for `enum` type. At least one value is mandatory.
                     Examples:

                         status:enum:[published,unpublished]

               * `assoc,value` - Association name for `references`. For cases when it cannot be inferred from the attribute name. Default to attribute name without suffix `_id`.
                     Examples:

                         booking_id:references:assoc,reservation

               * `column,value` - Referenced column name for `references`. For cases when it differs from default value `id`.
                     Examples:

                         book_id:references:column,isbn

               * `default,value` - Default option for `boolean`, `integer`, `decimal`, `float` types. For `boolean` type values `true`, `1` are the same, the rest is `false`.
                     Examples:

                         the_cake_is_a_lie:boolean:default,true
                         points:integer:default,0
                         price:decimal:default,0.0
                         sum:float:default,0.0

               * `index` - Adds index in migration.
                     Examples:

                         title:string:index

               * `on_delete,value` - What to do if the referenced entry is deleted. `value` may be `nothing` (default), `restrict`, `delete_all`, `nilify_all` or `nilify[columns]`. `nilify[columns]` expects a comma-separated list of columns and is not supported by all databases.
                     Examples:

                         author_id:references:on_delete,delete_all
                         book_id:references:on_delete,nilify[book_id,book_name]

               * `precision,value` - Number option for `decimal` type. Minimum is 2.
                     Examples:

                         price:decimal:precision,5

               * `redact` - Adds option to schema field.
                     Examples:

                         card_number:string:redact

               * `required` - Adds `null: false` constraint in migration, validation in schema, and mark in html input if no default option provided.
                     Examples:

                         title:string:required

               * `scale,value` - Number option for `decimal` type. Minimum is 1. `scale` can be provided only with `precision` option and should be less than it.
                     Examples:

                         price:decimal:precision,5:scale,2

               * `size,value` - Positive number option for `string` type.
                     Examples:

                         city:string:size,40

               * `table,value` - Table name for `references`. For cases when referenced schema is not reachable to reflect on.
                     Examples:

                         booking_id:references:table,reservations

               * `type,value` - Type of the column for `references`. For cases when referenced schema is not reachable to reflect on. Supported values: `id`, `binary_id`, `string`.
                     Examples:

                         book_id:references:type,id
                         book_id:references:type,binary_id
                         isbn:references:column,isbn:type,string

               * `unique` - Adds unique index in migration and validation in schema.
                     Examples:

                         title:string:unique

               * `virtual` - Adds option to schema field and omits migration changes. Can be used with type `any`.
                     Examples:

                         current_guess:integer:virtual
                         data:any:virtual
             """
  end

  test "type_specs/1 lists supported options for the given attribute's type, with details" do
    assert Attribute.type_specs(:string) ==
             """

             `string` - Default type. Can be omitted if no options are provided. Use `size` option to limit number of characters.

             `string` supports following options.

               * `*` - An alias for `required`.
                     Examples:

                         title:string:*

               * `index` - Adds index in migration.
                     Examples:

                         title:string:index

               * `redact` - Adds option to schema field.
                     Examples:

                         card_number:string:redact

               * `required` - Adds `null: false` constraint in migration, validation in schema, and mark in html input if no default option provided.
                     Examples:

                         title:string:required

               * `size,value` - Positive number option for `string` type.
                     Examples:

                         city:string:size,40

               * `unique` - Adds unique index in migration and validation in schema.
                     Examples:

                         title:string:unique

               * `virtual` - Adds option to schema field and omits migration changes. Can be used with type `any`.
                     Examples:

                         current_guess:integer:virtual
                         data:any:virtual
             """

    assert Attribute.type_specs(:enum) ==
             """

             `enum` - Requires at least one value in options. Values are translated into list or keyword list.

             `enum` supports following options.

               * `*` - An alias for `required`.
                     Examples:

                         title:string:*

               * `[[one,1],[two,2]]` - Keyword list of values for `enum` type. At least one value is mandatory.
                     Examples:

                         status:enum:[[published,1],[unpublished,2]]

               * `[one,two]` - List of values for `enum` type. At least one value is mandatory.
                     Examples:

                         status:enum:[published,unpublished]

               * `index` - Adds index in migration.
                     Examples:

                         title:string:index

               * `redact` - Adds option to schema field.
                     Examples:

                         card_number:string:redact

               * `required` - Adds `null: false` constraint in migration, validation in schema, and mark in html input if no default option provided.
                     Examples:

                         title:string:required

               * `unique` - Adds unique index in migration and validation in schema.
                     Examples:

                         title:string:unique

               * `virtual` - Adds option to schema field and omits migration changes. Can be used with type `any`.
                     Examples:

                         current_guess:integer:virtual
                         data:any:virtual
             """

    assert Attribute.type_specs(:references) ==
             """

             `references` - All info is inferred from the attribute name unless customized via options. Referenced schema is inferred in scope of the given context. Different schema can be provided in full form `Context.Schema` in options. Referenced schema should exist in the app.

             `references` supports following options.

               * `*` - An alias for `required`.
                     Examples:

                         title:string:*

               * `Context.Schema` - Referenced schema name for `references`. For cases when schema cannot be inferred from the attribute name, or context differs.
                     Examples:

                         author_id:references:Accounts.User

               * `assoc,value` - Association name for `references`. For cases when it cannot be inferred from the attribute name. Default to attribute name without suffix `_id`.
                     Examples:

                         booking_id:references:assoc,reservation

               * `column,value` - Referenced column name for `references`. For cases when it differs from default value `id`.
                     Examples:

                         book_id:references:column,isbn

               * `index` - Adds index in migration.
                     Examples:

                         title:string:index

               * `on_delete,value` - What to do if the referenced entry is deleted. `value` may be `nothing` (default), `restrict`, `delete_all`, `nilify_all` or `nilify[columns]`. `nilify[columns]` expects a comma-separated list of columns and is not supported by all databases.
                     Examples:

                         author_id:references:on_delete,delete_all
                         book_id:references:on_delete,nilify[book_id,book_name]

               * `redact` - Adds option to schema field.
                     Examples:

                         card_number:string:redact

               * `required` - Adds `null: false` constraint in migration, validation in schema, and mark in html input if no default option provided.
                     Examples:

                         title:string:required

               * `table,value` - Table name for `references`. For cases when referenced schema is not reachable to reflect on.
                     Examples:

                         booking_id:references:table,reservations

               * `type,value` - Type of the column for `references`. For cases when referenced schema is not reachable to reflect on. Supported values: `id`, `binary_id`, `string`.
                     Examples:

                         book_id:references:type,id
                         book_id:references:type,binary_id
                         isbn:references:column,isbn:type,string

               * `unique` - Adds unique index in migration and validation in schema.
                     Examples:

                         title:string:unique
             """
  end

  @parsed_attrs [
    %Attribute{name: :points, options: %{unique: true}, type: :integer},
    %Attribute{name: :price, options: %{}, type: :decimal},
    %Attribute{
      name: :the_cake_is_a_lie,
      type: :boolean,
      options: %{default: true, required: true}
    },
    %Attribute{name: :title, type: :string, options: %{index: true, required: true}},
    %Attribute{name: :card_number, type: :string, options: %{redact: true}},
    %Attribute{name: :name, options: %{}, type: :text},
    %Attribute{
      name: :post_id,
      type: :references,
      options: %{
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
        type: :id,
        table: "bookings",
        on_delete: :nothing,
        referenced_schema: TestApp.Blog.Booking
      }
    },
    %Attribute{name: :data, type: :any, options: %{virtual: true}},
    %Attribute{name: :tags, type: {:array, :integer}, options: %{}}
  ]

  test "sort/1 performs general sorting for attributes - by name with references at the end" do
    assert Attribute.sort(@parsed_attrs) == [
             %Attribute{name: :card_number, type: :string, options: %{redact: true}},
             %Attribute{name: :data, type: :any, options: %{virtual: true}},
             %Attribute{name: :name, type: :text, options: %{}},
             %Attribute{name: :points, type: :integer, options: %{unique: true}},
             %Attribute{name: :price, type: :decimal, options: %{}},
             %Attribute{name: :tags, type: {:array, :integer}, options: %{}},
             %Attribute{
               name: :the_cake_is_a_lie,
               type: :boolean,
               options: %{default: true, required: true}
             },
             %Attribute{name: :title, type: :string, options: %{index: true, required: true}},
             %Attribute{
               name: :booking_id,
               type: :references,
               options: %{
                 index: true,
                 unique: true,
                 association_name: :reservation,
                 type: :id,
                 table: "bookings",
                 on_delete: :nothing,
                 referenced_schema: TestApp.Blog.Booking
               }
             },
             %Attribute{
               name: :post_id,
               type: :references,
               options: %{
                 index: true,
                 association_name: :post,
                 type: :id,
                 table: "posts",
                 on_delete: :nothing,
                 referenced_schema: TestApp.Blog.Post
               }
             }
           ]
  end

  test "without_references/1 excludes references from attributes" do
    assert Attribute.without_references(@parsed_attrs) == [
             %Attribute{name: :points, type: :integer, options: %{unique: true}},
             %Attribute{name: :price, type: :decimal, options: %{}},
             %Attribute{
               name: :the_cake_is_a_lie,
               type: :boolean,
               options: %{default: true, required: true}
             },
             %Attribute{name: :title, type: :string, options: %{index: true, required: true}},
             %Attribute{name: :card_number, type: :string, options: %{redact: true}},
             %Attribute{name: :name, type: :text, options: %{}},
             %Attribute{name: :data, type: :any, options: %{virtual: true}},
             %Attribute{name: :tags, type: {:array, :integer}, options: %{}}
           ]
  end

  test "references/1 returns only references from attributes" do
    assert Attribute.references(@parsed_attrs) == [
             %Attribute{
               name: :post_id,
               type: :references,
               options: %{
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
                 type: :id,
                 table: "bookings",
                 on_delete: :nothing,
                 referenced_schema: TestApp.Blog.Booking
               }
             }
           ]
  end

  test "without_virtual/1 excludes virtual attributes" do
    assert Attribute.without_virtual(@parsed_attrs) == [
             %Attribute{name: :points, type: :integer, options: %{unique: true}},
             %Attribute{name: :price, type: :decimal, options: %{}},
             %Attribute{
               name: :the_cake_is_a_lie,
               type: :boolean,
               options: %{default: true, required: true}
             },
             %Attribute{name: :title, type: :string, options: %{index: true, required: true}},
             %Attribute{name: :card_number, type: :string, options: %{redact: true}},
             %Attribute{name: :name, type: :text, options: %{}},
             %Attribute{
               name: :post_id,
               type: :references,
               options: %{
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
                 type: :id,
                 table: "bookings",
                 on_delete: :nothing,
                 referenced_schema: TestApp.Blog.Booking
               }
             },
             %Attribute{name: :tags, type: {:array, :integer}, options: %{}}
           ]
  end

  test "virtual/1 returns only virtual attributes" do
    assert Attribute.virtual(@parsed_attrs) == [
             %Attribute{name: :data, type: :any, options: %{virtual: true}}
           ]
  end

  test "required/1 returns required attributes" do
    assert Attribute.required(@parsed_attrs) == [
             %Attribute{
               name: :the_cake_is_a_lie,
               type: :boolean,
               options: %{default: true, required: true}
             },
             %Attribute{name: :title, type: :string, options: %{index: true, required: true}}
           ]
  end

  test "unique/1 returns unique attributes" do
    assert Attribute.unique(@parsed_attrs) == [
             %Attribute{name: :points, type: :integer, options: %{unique: true}},
             %Attribute{
               name: :booking_id,
               type: :references,
               options: %{
                 index: true,
                 unique: true,
                 association_name: :reservation,
                 type: :id,
                 table: "bookings",
                 on_delete: :nothing,
                 referenced_schema: TestApp.Blog.Booking
               }
             }
           ]
  end

  test "indexed/1 returns attributes which have index (unique or general)" do
    assert Attribute.indexed(@parsed_attrs) == [
             %Attribute{name: :points, type: :integer, options: %{unique: true}},
             %Attribute{name: :title, type: :string, options: %{index: true, required: true}},
             %Attribute{
               name: :post_id,
               type: :references,
               options: %{
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
                 type: :id,
                 table: "bookings",
                 on_delete: :nothing,
                 referenced_schema: TestApp.Blog.Booking
               }
             }
           ]
  end

  test "adjust_decimal_value/2 returns adjusted decimal value to options precision and scale" do
    assert Attribute.adjust_decimal_value("456.789", %{}) == "456.789"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 8}) == "456.789"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 6}) == "456.789"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 4}) == "6.789"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 2}) == "6.7"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 2, scale: 1}) == "6.7"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 4, scale: 2}) == "56.78"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 5, scale: 4}) == "6.7890"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 7, scale: 5}) == "56.78900"
    assert Attribute.adjust_decimal_value("456.789", %{precision: 10, scale: 5}) == "456.78900"
  end
end
