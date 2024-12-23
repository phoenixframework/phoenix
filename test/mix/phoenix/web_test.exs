defmodule Mix.Phoenix.WebTest do
  use ExUnit.Case, async: true

  alias Mix.Phoenix.{Web, Schema, Attribute, TestData}

  @parsed_attrs [
    %Attribute{name: :points, options: %{unique: true}, type: :integer},
    %Attribute{name: :sum, options: %{}, type: :float},
    %Attribute{name: :price, options: %{precision: 10, scale: 5, unique: true}, type: :decimal},
    %Attribute{
      name: :the_cake_is_a_lie,
      type: :boolean,
      options: %{default: true, required: true}
    },
    %Attribute{name: :title, type: :string, options: %{unique: true, required: true}},
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
    %Attribute{
      name: :status,
      type: :enum,
      options: %{required: true, values: [:published, :unpublished]}
    },
    %Attribute{name: :status, type: :enum, options: %{values: [published: 1, unpublished: 2]}},
    %Attribute{
      name: :post_id,
      type: :references,
      options: %{
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
      name: :author_id,
      type: :references,
      options: %{
        required: true,
        index: true,
        association_name: :author,
        referenced_column: :id,
        referenced_type: :id,
        referenced_table: "users",
        on_delete: :nothing,
        association_schema: TestApp.Accounts.User
      }
    },
    %Attribute{
      name: :booking_id,
      type: :references,
      options: %{
        index: true,
        unique: true,
        association_name: :reservation,
        referenced_column: :id,
        referenced_type: :id,
        referenced_table: "bookings",
        on_delete: :nothing,
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
        on_delete: :nothing,
        association_schema: TestApp.Blog.Book
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

  test "live_table_columns/1 returns table columns for live index page, based on attributes, " <>
         "for array attribute adds `array_values(...)` wrapper to render values in basic manner" do
    schema = %Schema{singular: "comment", attrs: @parsed_attrs}

    assert Web.live_table_columns(schema) ==
             """

                   <:col :let={{_id, comment}} label="Points">{comment.points}</:col>
                   <:col :let={{_id, comment}} label="Sum">{comment.sum}</:col>
                   <:col :let={{_id, comment}} label="Price">{comment.price}</:col>
                   <:col :let={{_id, comment}} label="The cake is a lie">{comment.the_cake_is_a_lie}</:col>
                   <:col :let={{_id, comment}} label="Title">{comment.title}</:col>
                   <:col :let={{_id, comment}} label="Name">{comment.name}</:col>
                   <:col :let={{_id, comment}} label="Data">{comment.data}</:col>
                   <:col :let={{_id, comment}} label="Token">{comment.token}</:col>
                   <:col :let={{_id, comment}} label="Date of birth">{comment.date_of_birth}</:col>
                   <:col :let={{_id, comment}} label="Happy hour">{comment.happy_hour}</:col>
                   <:col :let={{_id, comment}} label="Happy hour">{comment.happy_hour}</:col>
                   <:col :let={{_id, comment}} label="Joined">{comment.joined}</:col>
                   <:col :let={{_id, comment}} label="Joined">{comment.joined}</:col>
                   <:col :let={{_id, comment}} label="Joined">{comment.joined}</:col>
                   <:col :let={{_id, comment}} label="Joined">{comment.joined}</:col>
                   <:col :let={{_id, comment}} label="Meta">{comment.meta}</:col>
                   <:col :let={{_id, comment}} label="Status">{comment.status}</:col>
                   <:col :let={{_id, comment}} label="Status">{comment.status}</:col>
                   <:col :let={{_id, comment}} label="Post">{comment.post_id}</:col>
                   <:col :let={{_id, comment}} label="Author">{comment.author_id}</:col>
                   <:col :let={{_id, comment}} label="Booking">{comment.booking_id}</:col>
                   <:col :let={{_id, comment}} label="Book">{comment.book_id}</:col>
                   <:col :let={{_id, comment}} label="Data">{comment.data}</:col>
                   <:col :let={{_id, comment}} label="Tags">{array_values(comment.tags)}</:col>
                   <:col :let={{_id, comment}} label="Tags">{array_values(comment.tags)}</:col>
                   <:col :let={{_id, comment}} label="Tags">{array_values(comment.tags)}</:col>
                   <:col :let={{_id, comment}} label="Tags">{array_values(comment.tags)}</:col>
             """
             |> String.trim_trailing("\n")
  end

  test "table_columns/1 returns table columns for html index page, based on attributes, " <>
         "for array attribute adds `array_values(...)` wrapper to render values in basic manner" do
    schema = %Schema{singular: "comment", attrs: @parsed_attrs}

    assert Web.table_columns(schema) ==
             """

               <:col :let={comment} label="Points">{comment.points}</:col>
               <:col :let={comment} label="Sum">{comment.sum}</:col>
               <:col :let={comment} label="Price">{comment.price}</:col>
               <:col :let={comment} label="The cake is a lie">{comment.the_cake_is_a_lie}</:col>
               <:col :let={comment} label="Title">{comment.title}</:col>
               <:col :let={comment} label="Name">{comment.name}</:col>
               <:col :let={comment} label="Data">{comment.data}</:col>
               <:col :let={comment} label="Token">{comment.token}</:col>
               <:col :let={comment} label="Date of birth">{comment.date_of_birth}</:col>
               <:col :let={comment} label="Happy hour">{comment.happy_hour}</:col>
               <:col :let={comment} label="Happy hour">{comment.happy_hour}</:col>
               <:col :let={comment} label="Joined">{comment.joined}</:col>
               <:col :let={comment} label="Joined">{comment.joined}</:col>
               <:col :let={comment} label="Joined">{comment.joined}</:col>
               <:col :let={comment} label="Joined">{comment.joined}</:col>
               <:col :let={comment} label="Meta">{comment.meta}</:col>
               <:col :let={comment} label="Status">{comment.status}</:col>
               <:col :let={comment} label="Status">{comment.status}</:col>
               <:col :let={comment} label="Post">{comment.post_id}</:col>
               <:col :let={comment} label="Author">{comment.author_id}</:col>
               <:col :let={comment} label="Booking">{comment.booking_id}</:col>
               <:col :let={comment} label="Book">{comment.book_id}</:col>
               <:col :let={comment} label="Data">{comment.data}</:col>
               <:col :let={comment} label="Tags">{array_values(comment.tags)}</:col>
               <:col :let={comment} label="Tags">{array_values(comment.tags)}</:col>
               <:col :let={comment} label="Tags">{array_values(comment.tags)}</:col>
               <:col :let={comment} label="Tags">{array_values(comment.tags)}</:col>
             """
             |> String.trim_trailing("\n")
  end

  test "list_items/1 returns list items for html and live show pages, based on attributes, " <>
         "for array attribute adds `array_values(...)` wrapper to render values in basic manner" do
    schema = %Schema{singular: "comment", attrs: @parsed_attrs}

    assert Web.list_items(schema) == [
             "<:item title=\"Points\">{@comment.points}</:item>",
             "<:item title=\"Sum\">{@comment.sum}</:item>",
             "<:item title=\"Price\">{@comment.price}</:item>",
             "<:item title=\"The cake is a lie\">{@comment.the_cake_is_a_lie}</:item>",
             "<:item title=\"Title\">{@comment.title}</:item>",
             "<:item title=\"Name\">{@comment.name}</:item>",
             "<:item title=\"Data\">{@comment.data}</:item>",
             "<:item title=\"Token\">{@comment.token}</:item>",
             "<:item title=\"Date of birth\">{@comment.date_of_birth}</:item>",
             "<:item title=\"Happy hour\">{@comment.happy_hour}</:item>",
             "<:item title=\"Happy hour\">{@comment.happy_hour}</:item>",
             "<:item title=\"Joined\">{@comment.joined}</:item>",
             "<:item title=\"Joined\">{@comment.joined}</:item>",
             "<:item title=\"Joined\">{@comment.joined}</:item>",
             "<:item title=\"Joined\">{@comment.joined}</:item>",
             "<:item title=\"Meta\">{@comment.meta}</:item>",
             "<:item title=\"Status\">{@comment.status}</:item>",
             "<:item title=\"Status\">{@comment.status}</:item>",
             "<:item title=\"Post\">{@comment.post_id}</:item>",
             "<:item title=\"Author\">{@comment.author_id}</:item>",
             "<:item title=\"Booking\">{@comment.booking_id}</:item>",
             "<:item title=\"Book\">{@comment.book_id}</:item>",
             "<:item title=\"Data\">{@comment.data}</:item>",
             "<:item title=\"Tags\">{array_values(@comment.tags)}</:item>",
             "<:item title=\"Tags\">{array_values(@comment.tags)}</:item>",
             "<:item title=\"Tags\">{array_values(@comment.tags)}</:item>",
             "<:item title=\"Tags\">{array_values(@comment.tags)}</:item>"
           ]
  end

  test "maybe_def_array_values/2 returns implementation of `array_values(...)` wrapper " <>
         "to render values in basic manner, if there is an array attribute" do
    schema = %Schema{attrs: @parsed_attrs}

    assert Web.maybe_def_array_values(schema) ==
             """


               defp array_values(values), do: (values || []) |> List.flatten() |> Enum.join(", ")
             """
             |> String.trim_trailing("\n")

    assert Web.maybe_def_array_values(schema, :def) ==
             """


               def array_values(values), do: (values || []) |> List.flatten() |> Enum.join(", ")
             """
             |> String.trim_trailing("\n")

    attrs_without_array = [
      %Attribute{name: :points, options: %{unique: true}, type: :integer},
      %Attribute{name: :sum, options: %{}, type: :float},
      %Attribute{name: :price, options: %{precision: 10, scale: 5, unique: true}, type: :decimal}
    ]

    schema = %Schema{attrs: attrs_without_array}

    assert Web.maybe_def_array_values(schema) == nil
  end

  test "form_inputs/1 returns form inputs for html and live, based on attributes, " <>
         "takes into account types and options of attributes" do
    attrs = @parsed_attrs
    sample_values = TestData.sample_values(attrs, TestApp.Blog.Comment)
    schema = %Schema{module: TestApp.Blog.Comment, attrs: attrs, sample_values: sample_values}

    assert Web.form_inputs(schema, "test_form") ==
             """
             <.input field={test_form[:points]} label="Points" type="number" />
             <.input field={test_form[:sum]} label="Sum" type="number" step="any" />
             <.input field={test_form[:price]} label="Price" type="number" step="any" />
             <.input field={test_form[:the_cake_is_a_lie]} label="The cake is a lie" type="checkbox" />
             <.input field={test_form[:title]} label="Title" type="text" required />
             <.input field={test_form[:name]} label="Name" type="textarea" />
             <.input field={test_form[:data]} label="Data" type="text" />
             <.input field={test_form[:token]} label="Token" type="text" />
             <.input field={test_form[:date_of_birth]} label="Date of birth" type="date" />
             <.input field={test_form[:happy_hour]} label="Happy hour" type="time" />
             <.input field={test_form[:happy_hour]} label="Happy hour" type="text" />
             <.input field={test_form[:joined]} label="Joined" type="datetime-local" />
             <.input field={test_form[:joined]} label="Joined" type="text" />
             <.input field={test_form[:joined]} label="Joined" type="datetime-local" />
             <.input field={test_form[:joined]} label="Joined" type="text" />
             <.input field={test_form[:status]} label="Status" type="select" options={Ecto.Enum.values(TestApp.Blog.Comment, :status)} prompt="Choose a value" required />
             <.input field={test_form[:status]} label="Status" type="select" options={Ecto.Enum.values(TestApp.Blog.Comment, :status)} prompt="Choose a value" />
             <.input field={test_form[:post_id]} label="Post" type="text" />
             <.input field={test_form[:author_id]} label="Author" type="text" required />
             <.input field={test_form[:booking_id]} label="Booking" type="text" />
             <.input field={test_form[:book_id]} label="Book" type="text" />
             <.input field={test_form[:data]} label="Data" type="text" />
             <.input field={test_form[:tags]} label="Tags" type="select" options={["tags value", "updated tags value"]} multiple />
             <.input field={test_form[:tags]} label="Tags" type="select" options={[142, 303]} multiple />
             <.input field={test_form[:tags]} label="Tags" type="select" options={Ecto.Enum.values(TestApp.Blog.Comment, :tags)} multiple />
             <.input field={test_form[:tags]} label="Tags" type="select" options={Ecto.Enum.values(TestApp.Blog.Comment, :tags)} multiple />
             """
             |> String.trim_trailing("\n")
  end
end
