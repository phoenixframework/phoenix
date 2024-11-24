defmodule Mix.Phoenix.TestDataTest do
  use ExUnit.Case, async: true

  alias Mix.Phoenix.{TestData, Schema, Attribute}

  @parsed_attrs [
    %Attribute{name: :points, options: %{unique: true}, type: :integer},
    %Attribute{name: :sum, options: %{}, type: :float},
    %Attribute{name: :price, options: %{precision: 10, scale: 5, unique: true}, type: :decimal},
    %Attribute{
      name: :the_cake_is_a_lie,
      type: :boolean,
      options: %{default: true, required: true, virtual: true}
    },
    %Attribute{name: :agreed, type: :boolean, options: %{default: false, required: true}},
    %Attribute{name: :title, type: :string, options: %{unique: true, required: true}},
    %Attribute{name: :title_limited, type: :string, options: %{size: 10}},
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
    %Attribute{name: :meta, type: :map, options: %{virtual: true}},
    %Attribute{name: :status, type: :enum, options: %{values: [:published, :unpublished]}},
    %Attribute{name: :status, type: :enum, options: %{values: [published: 1, unpublished: 2]}},
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
        type: :id,
        table: "users",
        on_delete: :nothing,
        referenced_schema: TestApp.Accounts.User
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
        on_delete: :nothing,
        referenced_schema: TestApp.Blog.Book
      }
    },
    %Attribute{name: :data, type: :any, options: %{virtual: true}},
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

  @one_day_in_seconds 24 * 3600

  defp date_value(:create), do: Date.add(date_value(:update), -1)
  defp date_value(:update), do: Date.utc_today()

  defp utc_datetime_value(:create) do
    DateTime.add(
      utc_datetime_value(:update),
      -@one_day_in_seconds,
      :second,
      Calendar.UTCOnlyTimeZoneDatabase
    )
  end

  defp utc_datetime_value(:update),
    do: DateTime.truncate(utc_datetime_usec_value(:update), :second)

  defp utc_datetime_usec_value(:create) do
    DateTime.add(
      utc_datetime_usec_value(:update),
      -@one_day_in_seconds,
      :second,
      Calendar.UTCOnlyTimeZoneDatabase
    )
  end

  defp utc_datetime_usec_value(:update),
    do: %{DateTime.utc_now() | second: 0, microsecond: {0, 6}}

  defp utc_naive_datetime_value(:create),
    do: NaiveDateTime.add(utc_naive_datetime_value(:update), -@one_day_in_seconds)

  defp utc_naive_datetime_value(:update),
    do: NaiveDateTime.truncate(utc_naive_datetime_usec_value(:update), :second)

  defp utc_naive_datetime_usec_value(:create),
    do: NaiveDateTime.add(utc_naive_datetime_usec_value(:update), -@one_day_in_seconds)

  defp utc_naive_datetime_usec_value(:update),
    do: %{NaiveDateTime.utc_now() | second: 0, microsecond: {0, 6}}

  test "virtual_clearance/1 clears virtual fields logic to be used in context test file" do
    schema = %Schema{singular: "comment", attrs: @parsed_attrs}

    assert TestData.virtual_clearance(schema) ==
             """

                   # NOTE: Virtual fields updated to defaults or nil before comparison.
                   comment = %{comment | data: nil, meta: nil, the_cake_is_a_lie: true}
             """
             |> String.trim_trailing("\n")
  end

  test "fixture/1 defaults fixture values for each type of attributes with unique functions" do
    attrs = @parsed_attrs
    sample_values = TestData.sample_values(attrs, TestApp.Blog.Comment)
    schema = %Schema{singular: "comment", attrs: attrs, sample_values: sample_values}

    assert TestData.fixture(schema) == %{
             attrs:
               """

                       agreed: false,
                       data: "data value",
                       data: "data value",
                       date_of_birth: #{date_value(:create) |> inspect()},
                       happy_hour: ~T[14:00:00],
                       happy_hour: ~T[14:00:00.000000],
                       joined: #{utc_naive_datetime_value(:create) |> inspect()},
                       joined: #{utc_naive_datetime_usec_value(:create) |> inspect()},
                       joined: #{utc_datetime_value(:create) |> inspect()},
                       joined: #{utc_datetime_usec_value(:create) |> inspect()},
                       meta: %{},
                       name: "name value",
                       points: unique_comment_points(),
                       price: unique_comment_price(),
                       status: :published,
                       status: :published,
                       sum: 120.5,
                       tags: ["tags value"],
                       tags: [142],
                       tags: [:published],
                       tags: [:published],
                       the_cake_is_a_lie: true,
                       title: unique_comment_title(),
                       title_limited: "title_limi",
                       token: "7488a646-e31f-11e4-aace-600308960662",
                       author_id: author.id,
                       book_id: book.id,
                       booking_id: reservation.id,
                       post_id: post.id
               """
               |> String.trim_trailing("\n"),
             unique_functions: %{
               title:
                 {"unique_comment_title",
                  """
                    def unique_comment_title, do: "\#{System.unique_integer([:positive])}title value"
                  """, false},
               points:
                 {"unique_comment_points",
                  """
                    def unique_comment_points, do: System.unique_integer([:positive])
                  """, false},
               price:
                 {"unique_comment_price",
                  """
                    def unique_comment_price do
                      raise "implement the logic to generate a unique comment price"
                    end
                  """, true}
             }
           }
  end

  test "live_invalid_attrs/1 returns invalid attributes used in live" do
    sample_values = TestData.sample_values(@parsed_attrs, TestApp.Blog.Comment)
    schema = %Schema{sample_values: sample_values}

    assert TestData.live_invalid_attrs(schema) ==
             """

                 agreed: false,
                 data: nil,
                 data: nil,
                 date_of_birth: nil,
                 happy_hour: nil,
                 happy_hour: nil,
                 joined: nil,
                 joined: nil,
                 joined: nil,
                 joined: nil,
                 meta: nil,
                 name: nil,
                 points: nil,
                 price: nil,
                 status: nil,
                 status: nil,
                 sum: nil,
                 tags: [],
                 tags: [],
                 tags: [],
                 tags: [],
                 the_cake_is_a_lie: false,
                 title: nil,
                 title_limited: nil,
                 token: nil,
                 author_id: nil,
                 book_id: nil,
                 booking_id: nil,
                 post_id: nil
             """
             |> String.trim_trailing("\n")
  end

  test "live_action_attrs_with_references/2 returns attributes with references used for `action` in live" do
    sample_values = TestData.sample_values(@parsed_attrs, TestApp.Blog.Comment)
    schema = %Schema{sample_values: sample_values}

    assert TestData.live_action_attrs_with_references(schema, :create) ==
             """
                   author = TestApp.AccountsFixtures.user_fixture()
                   book = book_fixture()
                   reservation = booking_fixture()
                   post = post_fixture()

                   create_attrs = %{
                     agreed: true,
                     data: "data value",
                     data: "data value",
                     date_of_birth: #{date_value(:create) |> Calendar.strftime("%Y-%m-%d") |> inspect()},
                     happy_hour: "14:00",
                     happy_hour: "14:00",
                     joined: #{utc_naive_datetime_value(:create) |> NaiveDateTime.to_iso8601() |> inspect()},
                     joined: #{utc_naive_datetime_usec_value(:create) |> NaiveDateTime.to_iso8601() |> inspect()},
                     joined: #{utc_datetime_value(:create) |> DateTime.to_iso8601() |> inspect()},
                     joined: #{utc_datetime_usec_value(:create) |> DateTime.to_iso8601() |> inspect()},
                     meta: %{},
                     name: "name value",
                     points: 142,
                     price: "22.50000",
                     status: :published,
                     status: :published,
                     sum: 120.5,
                     tags: ["tags value"],
                     tags: [142],
                     tags: [:published],
                     tags: [:published],
                     the_cake_is_a_lie: true,
                     title: "title value",
                     title_limited: "title_limi",
                     token: "7488a646-e31f-11e4-aace-600308960662",
                     author_id: author.id,
                     book_id: book.id,
                     booking_id: reservation.id,
                     post_id: post.id
                   }
             """
             |> String.trim_trailing("\n")

    assert TestData.live_action_attrs_with_references(schema, :update) ==
             """
                   author = TestApp.AccountsFixtures.user_fixture()
                   book = book_fixture()
                   reservation = booking_fixture()
                   post = post_fixture()

                   update_attrs = %{
                     agreed: false,
                     data: "updated data value",
                     data: "updated data value",
                     date_of_birth: #{date_value(:update) |> Calendar.strftime("%Y-%m-%d") |> inspect()},
                     happy_hour: "15:01",
                     happy_hour: "15:01",
                     joined: #{utc_naive_datetime_value(:update) |> NaiveDateTime.to_iso8601() |> inspect()},
                     joined: #{utc_naive_datetime_usec_value(:update) |> NaiveDateTime.to_iso8601() |> inspect()},
                     joined: #{utc_datetime_value(:update) |> DateTime.to_iso8601() |> inspect()},
                     joined: #{utc_datetime_usec_value(:update) |> DateTime.to_iso8601() |> inspect()},
                     meta: %{},
                     name: "updated name value",
                     points: 303,
                     price: "18.70000",
                     status: :unpublished,
                     status: :unpublished,
                     sum: 456.7,
                     tags: ["updated tags value"],
                     tags: [303],
                     tags: [:unpublished],
                     tags: [:unpublished],
                     the_cake_is_a_lie: false,
                     title: "updated title value",
                     title_limited: "updated ti",
                     token: "7488a646-e31f-11e4-aace-600308960668",
                     author_id: author.id,
                     book_id: book.id,
                     booking_id: reservation.id,
                     post_id: post.id
                   }
             """
             |> String.trim_trailing("\n")
  end

  test "action_attrs_with_references/2 returns attributes with references used for `action` in context, html, json" do
    sample_values = TestData.sample_values(@parsed_attrs, TestApp.Blog.Comment)
    schema = %Schema{sample_values: sample_values}

    assert TestData.action_attrs_with_references(schema, :create) ==
             """
                   author = TestApp.AccountsFixtures.user_fixture()
                   book = book_fixture()
                   reservation = booking_fixture()
                   post = post_fixture()

                   create_attrs = %{
                     agreed: true,
                     data: "data value",
                     data: "data value",
                     date_of_birth: #{date_value(:create) |> inspect()},
                     happy_hour: ~T[14:00:00],
                     happy_hour: ~T[14:00:00.000000],
                     joined: #{utc_naive_datetime_value(:create) |> inspect()},
                     joined: #{utc_naive_datetime_usec_value(:create) |> inspect()},
                     joined: #{utc_datetime_value(:create) |> inspect()},
                     joined: #{utc_datetime_usec_value(:create) |> inspect()},
                     meta: %{},
                     name: "name value",
                     points: 142,
                     price: "22.50000",
                     status: :published,
                     status: :published,
                     sum: 120.5,
                     tags: ["tags value"],
                     tags: [142],
                     tags: [:published],
                     tags: [:published],
                     the_cake_is_a_lie: true,
                     title: "title value",
                     title_limited: "title_limi",
                     token: "7488a646-e31f-11e4-aace-600308960662",
                     author_id: author.id,
                     book_id: book.id,
                     booking_id: reservation.id,
                     post_id: post.id
                   }
             """
             |> String.trim_trailing("\n")

    assert TestData.action_attrs_with_references(schema, :update) ==
             """
                   author = TestApp.AccountsFixtures.user_fixture()
                   book = book_fixture()
                   reservation = booking_fixture()
                   post = post_fixture()

                   update_attrs = %{
                     agreed: false,
                     data: "updated data value",
                     data: "updated data value",
                     date_of_birth: #{date_value(:update) |> inspect()},
                     happy_hour: ~T[15:01:01],
                     happy_hour: ~T[15:01:01.000000],
                     joined: #{utc_naive_datetime_value(:update) |> inspect()},
                     joined: #{utc_naive_datetime_usec_value(:update) |> inspect()},
                     joined: #{utc_datetime_value(:update) |> inspect()},
                     joined: #{utc_datetime_usec_value(:update) |> inspect()},
                     meta: %{},
                     name: "updated name value",
                     points: 303,
                     price: "18.70000",
                     status: :unpublished,
                     status: :unpublished,
                     sum: 456.7,
                     tags: ["updated tags value"],
                     tags: [303],
                     tags: [:unpublished],
                     tags: [:unpublished],
                     the_cake_is_a_lie: false,
                     title: "updated title value",
                     title_limited: "updated ti",
                     token: "7488a646-e31f-11e4-aace-600308960668",
                     author_id: author.id,
                     book_id: book.id,
                     booking_id: reservation.id,
                     post_id: post.id
                   }
             """
             |> String.trim_trailing("\n")
  end

  defp process_json_value(value),
    do: value |> Phoenix.json_library().encode!() |> Phoenix.json_library().decode!() |> inspect()

  test "json_values_assertions/2 returns values assertions used for `action` in json" do
    sample_values = TestData.sample_values(@parsed_attrs, TestApp.Blog.Comment)
    schema = %Schema{sample_values: sample_values}

    assert TestData.json_values_assertions(schema, :create) ==
             """
                            "id" => ^id,
                            "agreed" => true,
                            "data" => "data value",
                            "data" => nil,
                            "date_of_birth" => #{date_value(:create) |> process_json_value()},
                            "happy_hour" => "14:00:00",
                            "happy_hour" => "14:00:00.000000",
                            "joined" => #{utc_naive_datetime_value(:create) |> process_json_value()},
                            "joined" => #{utc_naive_datetime_usec_value(:create) |> process_json_value()},
                            "joined" => #{utc_datetime_value(:create) |> process_json_value()},
                            "joined" => #{utc_datetime_usec_value(:create) |> process_json_value()},
                            "meta" => nil,
                            "name" => "name value",
                            "points" => 142,
                            "price" => "22.50000",
                            "status" => "published",
                            "status" => "published",
                            "sum" => 120.5,
                            "tags" => ["tags value"],
                            "tags" => [142],
                            "tags" => ["published"],
                            "tags" => ["published"],
                            "the_cake_is_a_lie" => true,
                            "title" => "title value",
                            "title_limited" => "title_limi",
                            "token" => "7488a646-e31f-11e4-aace-600308960662",
                            "author_id" => json_author_id,
                            "book_id" => json_book_id,
                            "booking_id" => json_booking_id,
                            "post_id" => json_post_id
             """
             |> String.trim_trailing("\n")

    assert TestData.json_values_assertions(schema, :update) ==
             """
                            "id" => ^id,
                            "agreed" => false,
                            "data" => "updated data value",
                            "data" => nil,
                            "date_of_birth" => #{date_value(:update) |> process_json_value()},
                            "happy_hour" => "15:01:01",
                            "happy_hour" => "15:01:01.000000",
                            "joined" => #{utc_naive_datetime_value(:update) |> process_json_value()},
                            "joined" => #{utc_naive_datetime_usec_value(:update) |> process_json_value()},
                            "joined" => #{utc_datetime_value(:update) |> process_json_value()},
                            "joined" => #{utc_datetime_usec_value(:update) |> process_json_value()},
                            "meta" => nil,
                            "name" => "updated name value",
                            "points" => 303,
                            "price" => "18.70000",
                            "status" => "unpublished",
                            "status" => "unpublished",
                            "sum" => 456.7,
                            "tags" => ["updated tags value"],
                            "tags" => [303],
                            "tags" => ["unpublished"],
                            "tags" => ["unpublished"],
                            "the_cake_is_a_lie" => true,
                            "title" => "updated title value",
                            "title_limited" => "updated ti",
                            "token" => "7488a646-e31f-11e4-aace-600308960668",
                            "author_id" => json_author_id,
                            "book_id" => json_book_id,
                            "booking_id" => json_booking_id,
                            "post_id" => json_post_id
             """
             |> String.trim_trailing("\n")
  end

  test "json_references_values_assertions/2 returns values assertions used for references in json" do
    schema = %Schema{attrs: @parsed_attrs}

    assert TestData.json_references_values_assertions(schema) ==
             """


                   assert json_post_id == post.id
                   assert json_author_id == author.id
                   assert json_booking_id == reservation.id
                   assert json_book_id == book.id
             """
             |> String.trim_trailing("\n")
  end

  test "html_assertion_field/2 returns data to use in html assertions, if there is a suitable field" do
    sample_values = TestData.sample_values(@parsed_attrs, TestApp.Blog.Comment)
    schema = %Schema{attrs: @parsed_attrs, sample_values: sample_values}

    assert TestData.html_assertion_field(schema) == %{
             name: :title,
             create_value: "\"title value\"",
             update_value: "\"updated title value\""
           }
  end

  test "context_values_assertions/2 returns values assertions used for `action` in context" do
    sample_values = TestData.sample_values(@parsed_attrs, TestApp.Blog.Comment)
    schema = %Schema{singular: "comment", sample_values: sample_values}

    assert TestData.context_values_assertions(schema, :create) ==
             """
                   assert comment.agreed == true
                   assert comment.data == "data value"
                   assert comment.data == "data value"
                   assert comment.date_of_birth == #{date_value(:create) |> inspect()}
                   assert comment.happy_hour == ~T[14:00:00]
                   assert comment.happy_hour == ~T[14:00:00.000000]
                   assert comment.joined == #{utc_naive_datetime_value(:create) |> inspect()}
                   assert comment.joined == #{utc_naive_datetime_usec_value(:create) |> inspect()}
                   assert comment.joined == #{utc_datetime_value(:create) |> inspect()}
                   assert comment.joined == #{utc_datetime_usec_value(:create) |> inspect()}
                   assert comment.meta == %{}
                   assert comment.name == "name value"
                   assert comment.points == 142
                   assert comment.price == Decimal.new("22.50000")
                   assert comment.status == :published
                   assert comment.status == :published
                   assert comment.sum == 120.5
                   assert comment.tags == ["tags value"]
                   assert comment.tags == [142]
                   assert comment.tags == [:published]
                   assert comment.tags == [:published]
                   assert comment.the_cake_is_a_lie == true
                   assert comment.title == "title value"
                   assert comment.title_limited == "title_limi"
                   assert comment.token == "7488a646-e31f-11e4-aace-600308960662"
                   assert comment.author_id == author.id
                   assert comment.book_id == book.id
                   assert comment.booking_id == reservation.id
                   assert comment.post_id == post.id
             """
             |> String.trim_trailing("\n")

    assert TestData.context_values_assertions(schema, :update) ==
             """
                   assert comment.agreed == false
                   assert comment.data == "updated data value"
                   assert comment.data == "updated data value"
                   assert comment.date_of_birth == #{date_value(:update) |> inspect()}
                   assert comment.happy_hour == ~T[15:01:01]
                   assert comment.happy_hour == ~T[15:01:01.000000]
                   assert comment.joined == #{utc_naive_datetime_value(:update) |> inspect()}
                   assert comment.joined == #{utc_naive_datetime_usec_value(:update) |> inspect()}
                   assert comment.joined == #{utc_datetime_value(:update) |> inspect()}
                   assert comment.joined == #{utc_datetime_usec_value(:update) |> inspect()}
                   assert comment.meta == %{}
                   assert comment.name == "updated name value"
                   assert comment.points == 303
                   assert comment.price == Decimal.new("18.70000")
                   assert comment.status == :unpublished
                   assert comment.status == :unpublished
                   assert comment.sum == 456.7
                   assert comment.tags == ["updated tags value"]
                   assert comment.tags == [303]
                   assert comment.tags == [:unpublished]
                   assert comment.tags == [:unpublished]
                   assert comment.the_cake_is_a_lie == false
                   assert comment.title == "updated title value"
                   assert comment.title_limited == "updated ti"
                   assert comment.token == "7488a646-e31f-11e4-aace-600308960668"
                   assert comment.author_id == author.id
                   assert comment.book_id == book.id
                   assert comment.booking_id == reservation.id
                   assert comment.post_id == post.id
             """
             |> String.trim_trailing("\n")
  end

  test "sample_values/1 returns map of base sample attrs to be used in test files, " <>
         "specific formatting logic is invoked per case when it needed only (based on these data)" do
    assert TestData.sample_values(@parsed_attrs, TestApp.Blog.Comment) == %{
             invalid:
               "agreed: nil, " <>
                 "data: nil, " <>
                 "data: nil, " <>
                 "date_of_birth: nil, " <>
                 "happy_hour: nil, " <>
                 "happy_hour: nil, " <>
                 "joined: nil, " <>
                 "joined: nil, " <>
                 "joined: nil, " <>
                 "joined: nil, " <>
                 "meta: nil, " <>
                 "name: nil, " <>
                 "points: nil, " <>
                 "price: nil, " <>
                 "status: nil, " <>
                 "status: nil, " <>
                 "sum: nil, " <>
                 "tags: nil, " <>
                 "tags: nil, " <>
                 "tags: nil, " <>
                 "tags: nil, " <>
                 "the_cake_is_a_lie: nil, " <>
                 "title: nil, " <>
                 "title_limited: nil, " <>
                 "token: nil, " <>
                 "author_id: nil, " <>
                 "book_id: nil, " <>
                 "booking_id: nil, " <>
                 "post_id: nil",
             create: [
               {%Attribute{
                  name: :agreed,
                  type: :boolean,
                  options: %{default: false, required: true}
                }, true},
               {%Attribute{name: :data, type: :binary, options: %{}}, "data value"},
               {%Attribute{name: :data, type: :any, options: %{virtual: true}}, "data value"},
               {%Attribute{name: :date_of_birth, type: :date, options: %{}}, date_value(:create)},
               {%Attribute{name: :happy_hour, type: :time, options: %{}}, ~T[14:00:00]},
               {%Attribute{name: :happy_hour, type: :time_usec, options: %{}},
                ~T[14:00:00.000000]},
               {%Attribute{name: :joined, type: :naive_datetime, options: %{}},
                utc_naive_datetime_value(:create)},
               {%Attribute{name: :joined, type: :naive_datetime_usec, options: %{}},
                utc_naive_datetime_usec_value(:create)},
               {%Attribute{name: :joined, type: :utc_datetime, options: %{}},
                utc_datetime_value(:create)},
               {%Attribute{name: :joined, type: :utc_datetime_usec, options: %{}},
                utc_datetime_usec_value(:create)},
               {%Attribute{name: :meta, type: :map, options: %{virtual: true}}, %{}},
               {%Attribute{name: :name, type: :text, options: %{}}, "name value"},
               {%Attribute{name: :points, type: :integer, options: %{unique: true}}, 142},
               {%Attribute{
                  name: :price,
                  type: :decimal,
                  options: %{precision: 10, scale: 5, unique: true}
                }, "22.50000"},
               {%Attribute{
                  name: :status,
                  type: :enum,
                  options: %{values: [:published, :unpublished]}
                }, :published},
               {%Attribute{
                  name: :status,
                  type: :enum,
                  options: %{values: [published: 1, unpublished: 2]}
                }, :published},
               {%Attribute{name: :sum, type: :float, options: %{}}, 120.5},
               {%Attribute{name: :tags, type: {:array, :string}, options: %{}}, ["tags value"]},
               {%Attribute{name: :tags, type: {:array, :integer}, options: %{}}, [142]},
               {%Attribute{
                  name: :tags,
                  type: {:array, :enum},
                  options: %{values: [:published, :unpublished]}
                }, [:published]},
               {%Attribute{
                  name: :tags,
                  type: {:array, :enum},
                  options: %{values: [published: 1, unpublished: 2]}
                }, [:published]},
               {%Attribute{
                  name: :the_cake_is_a_lie,
                  type: :boolean,
                  options: %{default: true, required: true, virtual: true}
                }, true},
               {%Attribute{name: :title, type: :string, options: %{required: true, unique: true}},
                "title value"},
               {%Attribute{name: :title_limited, type: :string, options: %{size: 10}},
                "title_limi"},
               {%Attribute{name: :token, type: :uuid, options: %{}},
                "7488a646-e31f-11e4-aace-600308960662"},
               {%Attribute{
                  name: :author_id,
                  type: :references,
                  options: %{
                    index: true,
                    association_name: :author,
                    type: :id,
                    table: "users",
                    on_delete: :nothing,
                    referenced_schema: TestApp.Accounts.User
                  }
                }, "author.id"},
               {%Attribute{
                  name: :book_id,
                  type: :references,
                  options: %{
                    index: true,
                    association_name: :book,
                    column: :isbn,
                    type: :string,
                    table: "books",
                    on_delete: :nothing,
                    referenced_schema: TestApp.Blog.Book
                  }
                }, "book.id"},
               {%Attribute{
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
                }, "reservation.id"},
               {%Attribute{
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
                }, "post.id"}
             ],
             update: [
               {%Attribute{
                  name: :agreed,
                  type: :boolean,
                  options: %{default: false, required: true}
                }, false},
               {%Attribute{name: :data, type: :binary, options: %{}}, "updated data value"},
               {%Attribute{name: :data, type: :any, options: %{virtual: true}},
                "updated data value"},
               {%Attribute{name: :date_of_birth, type: :date, options: %{}}, date_value(:update)},
               {%Attribute{name: :happy_hour, type: :time, options: %{}}, ~T[15:01:01]},
               {%Attribute{name: :happy_hour, type: :time_usec, options: %{}},
                ~T[15:01:01.000000]},
               {%Attribute{name: :joined, type: :naive_datetime, options: %{}},
                utc_naive_datetime_value(:update)},
               {%Attribute{name: :joined, type: :naive_datetime_usec, options: %{}},
                utc_naive_datetime_usec_value(:update)},
               {%Attribute{name: :joined, type: :utc_datetime, options: %{}},
                utc_datetime_value(:update)},
               {%Attribute{name: :joined, type: :utc_datetime_usec, options: %{}},
                utc_datetime_usec_value(:update)},
               {%Attribute{name: :meta, type: :map, options: %{virtual: true}}, %{}},
               {%Attribute{name: :name, type: :text, options: %{}}, "updated name value"},
               {%Attribute{name: :points, type: :integer, options: %{unique: true}}, 303},
               {%Attribute{
                  name: :price,
                  type: :decimal,
                  options: %{precision: 10, scale: 5, unique: true}
                }, "18.70000"},
               {%Attribute{
                  name: :status,
                  type: :enum,
                  options: %{values: [:published, :unpublished]}
                }, :unpublished},
               {%Attribute{
                  name: :status,
                  type: :enum,
                  options: %{values: [published: 1, unpublished: 2]}
                }, :unpublished},
               {%Attribute{name: :sum, type: :float, options: %{}}, 456.7},
               {%Attribute{name: :tags, type: {:array, :string}, options: %{}},
                ["updated tags value"]},
               {%Attribute{name: :tags, type: {:array, :integer}, options: %{}}, [303]},
               {%Attribute{
                  name: :tags,
                  type: {:array, :enum},
                  options: %{values: [:published, :unpublished]}
                }, [:unpublished]},
               {%Attribute{
                  name: :tags,
                  type: {:array, :enum},
                  options: %{values: [published: 1, unpublished: 2]}
                }, [:unpublished]},
               {%Attribute{
                  name: :the_cake_is_a_lie,
                  type: :boolean,
                  options: %{default: true, required: true, virtual: true}
                }, false},
               {%Attribute{
                  name: :title,
                  type: :string,
                  options: %{required: true, unique: true}
                }, "updated title value"},
               {%Attribute{name: :title_limited, type: :string, options: %{size: 10}},
                "updated ti"},
               {%Attribute{name: :token, type: :uuid, options: %{}},
                "7488a646-e31f-11e4-aace-600308960668"},
               {%Attribute{
                  name: :author_id,
                  type: :references,
                  options: %{
                    index: true,
                    association_name: :author,
                    type: :id,
                    table: "users",
                    on_delete: :nothing,
                    referenced_schema: TestApp.Accounts.User
                  }
                }, "author.id"},
               {%Attribute{
                  name: :book_id,
                  type: :references,
                  options: %{
                    index: true,
                    association_name: :book,
                    column: :isbn,
                    type: :string,
                    table: "books",
                    on_delete: :nothing,
                    referenced_schema: TestApp.Blog.Book
                  }
                }, "book.id"},
               {%Attribute{
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
                }, "reservation.id"},
               {%Attribute{
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
                }, "post.id"}
             ],
             references_assigns: [
               "author = TestApp.AccountsFixtures.user_fixture()",
               "book = book_fixture()",
               "reservation = booking_fixture()",
               "post = post_fixture()"
             ]
           }
  end
end
