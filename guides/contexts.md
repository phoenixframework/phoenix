# Contexts

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [Request life-cycle guide](request_lifecycle.html).

> **Requirement**: This guide expects that you have gone through the [Ecto guide](ecto.html).

So far, we've built pages, wired up controller actions through our routers, and learned how Ecto allows data to be validated and persisted. Now it's time to tie it all together by writing web-facing features that interact with our greater Elixir application.

When building a Phoenix project, we are first and foremost building an Elixir application. Phoenix's job is to provide a web interface into our Elixir application. Naturally, we compose our applications with modules and functions, but simply defining a module with a few functions isn't enough when designing an application. We need to consider the boundaries between modules and how to group functionality. In other words, it's vital to think about application design when writing code.

## Thinking about design

Contexts are dedicated modules that expose and group related functionality. For example, anytime you call Elixir's standard library, be it `Logger.info/1` or `Stream.map/2`, you are accessing different contexts. Internally, Elixir's logger is made of multiple modules, but we never interact with those modules directly. We call the `Logger` module the context, exactly because it exposes and groups all of the logging functionality.

By giving modules that expose and group related functionality the name **contexts**, we help developers identify these patterns and talk about them. At the end of the day, contexts are just modules, as are your controllers, views, etc.

In Phoenix, contexts often encapsulate data access and data validation. They often talk to a database or APIs. Overall, think of them as boundaries to decouple and isolate parts of your application. Let's use these ideas to build out our web application. Our goal is to build an ecommerce system where we can showcase products, allow users to add products to their cart, and complete their orders.

> How to read this guide: Using the context generators is a great way for beginners and intermediate Elixir programmers alike to get up and running quickly while thoughtfully designing their applications. This guide focuses on those readers.

### Adding a Catalog Context

An ecommerce platform has wide-reaching coupling across a codebase so it's important to think upfront about writing well-defined interfaces. With that in mind, our goal is to build a product catalog API that handles creating, updating, and deleting the products available in our system. We'll start off with the basic features of showcasing our products, and we will add shopping cart features later. We'll see how starting with a solid foundation with isolated boundaries allows us to grow our application naturally as we add functionality.

Phoenix includes the `mix phx.gen.html`, `mix phx.gen.json`, `mix phx.gen.live`, and `mix phx.gen.context` generators that apply the ideas of isolating functionality in our applications into contexts. These generators are a great way to hit the ground running while Phoenix nudges you in the right direction to grow your application. Let's put these tools to use for our new product catalog context.

In order to run the context generators, we need to come up with a module name that groups the related functionality that we're building. In the [Ecto guide](ecto.html), we saw how we can use Changesets and Repos to validate and persist user schemas, but we didn't integrate this with our application at large. In fact, we didn't think about where a "user" in our application should live at all. Let's take a step back and think about the different parts of our system. We know that we'll have products to showcase on pages for sale, along with descriptions, pricing, etc. Along with selling products, we know we'll need to support carting, order checkout, and so on. While the products being purchased are related to the cart and checkout processes, showcasing a product and managing the *exhibition* of our products is distinctly different than tracking what a user has placed in their cart or how an order is placed. A `Catalog` context is a natural place for the management of our product details and the showcasing of those products we have for sale.

> Naming things is hard. If you're stuck when trying to come up with a context name when the grouped functionality in your system isn't yet clear, you can simply use the plural form of the resource you're creating. For example, a `Products` context for managing products. As you grow your application and the parts of your system become clear, you can simply rename the context to a more refined one.

To jump-start our catalog context, we'll use `mix phx.gen.html` which creates a context module that wraps up Ecto access for creating, updating, and deleting products, along with web files like controllers and templates for the web interface into our context. Run the following command at your project root:

```console
$ mix phx.gen.html Catalog Product products title:string \
description:string price:decimal views:integer

* creating lib/hello_web/controllers/product_controller.ex
* creating lib/hello_web/controllers/product_html/edit.html.heex
* creating lib/hello_web/controllers/product_html/form.html.heex
* creating lib/hello_web/controllers/product_html/index.html.heex
* creating lib/hello_web/controllers/product_html/new.html.heex
* creating lib/hello_web/controllers/product_html/show.html.heex
* creating lib/hello_web/controllers/product_html.ex
* creating test/hello_web/controllers/product_controller_test.exs
* creating lib/hello/catalog/product.ex
* creating priv/repo/migrations/20210201185747_create_products.exs
* creating lib/hello/catalog.ex
* injecting lib/hello/catalog.ex
* creating test/hello/catalog_test.exs
* injecting test/hello/catalog_test.exs
* creating test/support/fixtures/catalog_fixtures.ex
* injecting test/support/fixtures/catalog_fixtures.ex

Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/products", ProductController


Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

> Note: we are starting with the basics for modeling an ecommerce system. In practice, modeling such systems yields more complex relationships such as product variants, optional pricing, multiple currencies, etc. We'll keep things simple in this guide, but the foundations will give you a solid starting point to building such a complete system.

Phoenix generated the web files as expected in `lib/hello_web/`. We can also see our context files were generated inside a `lib/hello/catalog.ex` file and our product schema in the directory of the same name. Note the difference between `lib/hello` and `lib/hello_web`. We have a `Catalog` module to serve as the public API for product catalog functionality, as well as a `Catalog.Product` struct, which is an Ecto schema for casting and validating product data. Phoenix also provided web and context tests for us, it also included test helpers for creating entities via the `Hello.Catalog` context, which we'll look at later. For now, let's follow the instructions and add the route according to the console instructions, in `lib/hello_web/router.ex`:

```diff
  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :index
+   resources "/products", ProductController
  end
```

With the new route in place, Phoenix reminds us to update our repo by running `mix ecto.migrate`, but first we need to make a few tweaks to the generated migration in `priv/repo/migrations/*_create_products.exs`:

```elixir
  def change do
    create table(:products) do
      add :title, :string
      add :description, :string
-     add :price, :decimal
+     add :price, :decimal, precision: 15, scale: 6, null: false
-     add :views, :integer
+     add :views, :integer, default: 0, null: false

      timestamps()
    end
```

We modified our price column to a specific precision of 15, scale of 6, along with a not-null constraint. This ensures we store currency with proper precision for any mathematical operations we may perform. Next, we added a default value and not-null constraint to our views count. With our changes in place, we're ready to migrate up our database. Let's do that now:

```console
$ mix ecto.migrate
14:09:02.260 [info] == Running 20210201185747 Hello.Repo.Migrations.CreateProducts.change/0 forward

14:09:02.262 [info] create table products

14:09:02.273 [info] == Migrated 20210201185747 in 0.0s
```

Before we jump into the generated code, let's start the server with `mix phx.server` and visit [http://localhost:4000/products](http://localhost:4000/products). Let's follow the "New Product" link and click the "Save" button without providing any input. We should be greeted with the following output:

```text
Oops, something went wrong! Please check the errors below.
```

When we submit the form, we can see all the validation errors inline with the inputs. Nice! Out of the box, the context generator included the schema fields in our form template and we can see our default validations for required inputs are in effect. Let's enter some example product data and resubmit the form:

```text
Product created successfully.

Title: Metaprogramming Elixir
Description: Write Less Code, Get More Done (and Have Fun!)
Price: 15.000000
Views: 0
```

If we follow the "Back" link, we get a list of all products, which should contain the one we just created. Likewise, we can update this record or delete it. Now that we've seen how it works in the browser, it's time to take a look at the generated code.

## Starting With Generators

That little `mix phx.gen.html` command packed a surprising punch. We got a lot of functionality out-of-the-box for creating, updating, and deleting products in our catalog. This is far from a full-featured app, but remember, generators are first and foremost learning tools and a starting point for you to begin building real features. Code generation can't solve all your problems, but it will teach you the ins and outs of Phoenix and nudge you towards the proper mindset when designing your application.

Let's first check out the `ProductController` that was generated in `lib/hello_web/controllers/product_controller.ex`:

```elixir
defmodule HelloWeb.ProductController do
  use HelloWeb, :controller

  alias Hello.Catalog
  alias Hello.Catalog.Product

  def index(conn, _params) do
    products = Catalog.list_products()
    render(conn, :index, products: products)
  end

  def new(conn, _params) do
    changeset = Catalog.change_product(%Product{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"product" => product_params}) do
    case Catalog.create_product(product_params) do
      {:ok, product} ->
        conn
        |> put_flash(:info, "Product created successfully.")
        |> redirect(to: ~p"/products/#{product}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    product = Catalog.get_product!(id)
    render(conn, :show, product: product)
  end
  ...
end
```

We've seen how controllers work in our [controller guide](controllers.html), so the code probably isn't too surprising. What is worth noticing is how our controller calls into the `Catalog` context. We can see that the `index` action fetches a list of products with `Catalog.list_products/0`, and how products are persisted in the `create` action with `Catalog.create_product/1`. We haven't yet looked at the catalog context, so we don't yet know how product fetching and creation is happening under the hood – *but that's the point*. Our Phoenix controller is the web interface into our greater application. It shouldn't be concerned with the details of how products are fetched from the database or persisted into storage. We only care about telling our application to perform some work for us. This is great because our business logic and storage details are decoupled from the web layer of our application. If we move to a full-text storage engine later for fetching products instead of a SQL query, our controller doesn't need to be changed. Likewise, we can reuse our context code from any other interface in our application, be it a channel, mix task, or long-running process importing CSV data.

In the case of our `create` action, when we successfully create a product, we use `Phoenix.Controller.put_flash/3` to show a success message, and then we redirect to the router's product show page. Conversely, if `Catalog.create_product/1` fails, we render our `"new.html"` template and pass along the Ecto changeset for the template to lift error messages from.

Next, let's dig deeper and check out our `Catalog` context in `lib/hello/catalog.ex`:

```elixir
defmodule Hello.Catalog do
  @moduledoc """
  The Catalog context.
  """

  import Ecto.Query, warn: false
  alias Hello.Repo

  alias Hello.Catalog.Product

  @doc """
  Returns the list of products.

  ## Examples

      iex> list_products()
      [%Product{}, ...]

  """
  def list_products do
    Repo.all(Product)
  end
  ...
end
```

This module will be the public API for all product catalog functionality in our system. For example, in addition to product detail management, we may also handle product category classification and product variants for things like optional sizing, trims, etc. If we look at the `list_products/0` function, we can see the private details of product fetching. And it's super simple. We have a call to `Repo.all(Product)`. We saw how Ecto repo queries worked in the [Ecto guide](ecto.html), so this call should look familiar. Our `list_products` function is a generalized function name specifying the *intent* of our code – namely to list products. The details of that intent where we use our Repo to fetch the products from our PostgreSQL database is hidden from our callers. This is a common theme we'll see re-iterated as we use the Phoenix generators. Phoenix will push us to think about where we have different responsibilities in our application, and then to wrap up those different areas behind well-named modules and functions that make the intent of our code clear, while encapsulating the details.

Now we know how data is fetched, but how are products persisted? Let's take a look at the `Catalog.create_product/1` function:

```elixir
  @doc """
  Creates a product.

  ## Examples

      iex> create_product(%{field: value})
      {:ok, %Product{}}

      iex> create_product(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end
```

There's more documentation than code here, but a couple of things are important to highlight. First, we can see again that our Ecto Repo is used under the hood for database access. You probably also noticed the call to `Product.changeset/2`. We talked about changesets before, and now we see them in action in our context.

If we open up the `Product` schema in `lib/hello/catalog/product.ex`, it will look immediately familiar:

```elixir
defmodule Hello.Catalog.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :description, :string
    field :price, :decimal
    field :title, :string
    field :views, :integer

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:title, :description, :price, :views])
    |> validate_required([:title, :description, :price, :views])
  end
end
```

This is just what we saw before when we ran `mix phx.gen.schema`, except here we see a `@doc false` above our `changeset/2` function. This tells us that while this function is publicly callable, it's not part of the public context API. Callers that build changesets do so via the context API. For example, `Catalog.create_product/1` calls into our `Product.changeset/2` to build the changeset from user input. Callers, such as our controller actions, do not access `Product.changeset/2` directly. All interaction with our product changesets is done through the public `Catalog` context.

## Adding Catalog functions

As we've seen, your context modules are dedicated modules that expose and group related functionality. Phoenix generates generic functions, such as `list_products` and `update_product`, but they only serve as a basis for you to grow your business logic and application from. Let's add one of the basic features of our catalog by tracking product page view count.

For any ecommerce system, the ability to track how many times a product page has been viewed is essential for marketing, suggestions, ranking, etc. While we could try to use the existing `Catalog.update_product` function, along the lines of `Catalog.update_product(product, %{views: product.views + 1})`, this would not only be prone to race conditions, but it would also require the caller to know too much about our Catalog system. To see why the race condition exists, let's walk through the possible execution of events:

Intuitively, you would assume the following events:

  1. User 1 loads the product page with count of 13
  2. User 1 saves the product page with count of 14
  3. User 2 loads the product page with count of 14
  4. User 2 saves the product page with count of 15

While in practice this would happen:

  1. User 1 loads the product page with count of 13
  2. User 2 loads the product page with count of 13
  3. User 1 saves the product page with count of 14
  4. User 2 saves the product page with count of 14

The race conditions would make this an unreliable way to update the existing table since multiple callers may be updating out of date view values. There's a better way.

Let's think of a function that describes what we want to accomplish. Here's how we would like to use it:

```elixir
product = Catalog.inc_page_views(product)
```

That looks great. Our callers will have no confusion over what this function does, and we can wrap up the increment in an atomic operation to prevent race conditions.

Open up your catalog context (`lib/hello/catalog.ex`), and add this new function:

```elixir
  def inc_page_views(%Product{} = product) do
    {1, [%Product{views: views}]} =
      from(p in Product, where: p.id == ^product.id, select: [:views])
      |> Repo.update_all(inc: [views: 1])

    put_in(product.views, views)
  end
```

We built a query for fetching the current product given its ID which we pass to `Repo.update_all`. Ecto's `Repo.update_all` allows us to perform batch updates against the database, and is perfect for atomically updating values, such as incrementing our views count. The result of the repo operation returns the number of updated records, along with the selected schema values specified by the `select` option. When we receive the new product views, we use `put_in(product.views, views)` to place the new view count within the product struct.

With our context function in place, let's make use of it in our product controller. Update your `show` action in `lib/hello_web/controllers/product_controller.ex` to call our new function:

```elixir
  def show(conn, %{"id" => id}) do
    product =
      id
      |> Catalog.get_product!()
      |> Catalog.inc_page_views()

    render(conn, :show, product: product)
  end
```

We modified our `show` action to pipe our fetched product into `Catalog.inc_page_views/1`, which will return the updated product. Then we rendered our template just as before. Let's try it out. Refresh one of your product pages a few times and watch the view count increase.

We can also see our atomic update in action in the ecto debug logs:

```text
[debug] QUERY OK source="products" db=0.5ms idle=834.5ms
UPDATE "products" AS p0 SET "views" = p0."views" + $1 WHERE (p0."id" = $2) RETURNING p0."views" [1, 1]
```

Good work!

As we've seen, designing with contexts gives you a solid foundation to grow your application from. Using discrete, well-defined APIs that expose the intent of your system allows you to write more maintainable applications with reusable code. Now that we know how to start extending our context API, lets explore handling relationships within a context.

## In-context Relationships

Our basic catalog features are nice, but let's take it up a notch by categorizing products. Many ecommerce solutions allow products to be categorized in different ways, such as a product being marked for fashion, power tools, and so on. Starting with a one-to-one relationship between product and categories will cause major code changes later if we need to start supporting multiple categories. Let's set up a category association that will allow us to start off tracking a single category per product, but easily support more later as we grow our features.

For now, categories will contain only textual information. Our first order of business is to decide where categories live in the application. We have our `Catalog` context, which manages the exhibition of our products. Product categorization is a natural fit here. Phoenix is also smart enough to generate code inside an existing context, which makes adding new resources to a context a breeze. Run the following command at your project root:

> Sometimes it may be tricky to determine if two resources belong to the same context or not. In those cases, prefer distinct contexts per resource and refactor later if necessary. Otherwise you can easily end up with large contexts of loosely related entities. Also keep in mind that the fact two resources are related does not necessarily mean they belong to the same context, otherwise you would quickly end up with one large context, as the majority of resources in an application are connected to each other. To sum it up: if you are unsure, you should prefer separate modules (contexts).

```console
$ mix phx.gen.context Catalog Category categories \
title:string:unique

You are generating into an existing context.
...
Would you like to proceed? [Yn] y
* creating lib/hello/catalog/category.ex
* creating priv/repo/migrations/20210203192325_create_categories.exs
* injecting lib/hello/catalog.ex
* injecting test/hello/catalog_test.exs
* injecting test/support/fixtures/catalog_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

This time around, we used `mix phx.gen.context`, which is just like `mix phx.gen.html`, except it doesn't generate the web files for us. Since we already have controllers and templates for managing products, we can integrate the new category features into our existing web form and product show page. We can see we now have a new `Category` schema alongside our product schema at `lib/hello/catalog/category.ex`, and Phoenix told us it was *injecting* new functions in our existing Catalog context for the category functionality. The injected functions will look very familiar to our product functions, with new functions like `create_category`, `list_categories`, and so on. Before we migrate up, we need to do a second bit of code generation. Our category schema is great for representing an individual category in the system, but we need to support a many-to-many relationship between products and categories. Fortunately, ecto allows us to do this simply with a join table, so let's generate that now with the `ecto.gen.migration` command:

```console
$ mix ecto.gen.migration create_product_categories

* creating priv/repo/migrations/20210203192958_create_product_categories.exs
```

Next, let's open up the new migration file and add the following code to the `change` function:

```elixir

defmodule Hello.Repo.Migrations.CreateProductCategories do
  use Ecto.Migration

  def change do
    create table(:product_categories, primary_key: false) do
      add :product_id, references(:products, on_delete: :delete_all)
      add :category_id, references(:categories, on_delete: :delete_all)
    end

    create index(:product_categories, [:product_id])
    create unique_index(:product_categories, [:category_id, :product_id])
  end
end
```

We created a `product_categories` table and used the `primary_key: false` option since our join table does not need a primary key. Next we defined our `:product_id` and `:category_id` foreign key fields, and passed `on_delete: :delete_all` to ensure the database prunes our join table records if a linked product or category is deleted. By using a database constraint, we enforce data integrity at the database level, rather than relying on ad-hoc and error-prone application logic.

Next, we created indexes for our foreign keys, one of which is a unique index to ensure a product cannot have duplicate categories. Note that we do not necessarily need single-column index for `category_id` because it is in the leftmost prefix of multicolumn index, which is enough for the database optimizer. Adding a redundant index, on the other hand, only adds overhead on write.

With our migrations in place, we can migrate up.

```console
$ mix ecto.migrate

18:20:36.489 [info] == Running 20210222231834 Hello.Repo.Migrations.CreateCategories.change/0 forward

18:20:36.493 [info] create table categories

18:20:36.508 [info] create index categories_title_index

18:20:36.512 [info] == Migrated 20210222231834 in 0.0s

18:20:36.547 [info] == Running 20210222231930 Hello.Repo.Migrations.CreateProductCategories.change/0 forward

18:20:36.547 [info] create table product_categories

18:20:36.557 [info] create index product_categories_product_id_index

18:20:36.560 [info]  create index product_categories_category_id_product_id_index

18:20:36.562 [info] == Migrated 20210222231930 in 0.0s
```

Now that we have a `Catalog.Product` schema and a join table to associate products and categories, we're nearly ready to start wiring up our new features. Before we dive in, we first need real categories to select in our web UI. Let's quickly seed some new categories in the application. Add the following code to your seeds file in `priv/repo/seeds.exs`:

```elixir
for title <- ["Home Improvement", "Power Tools", "Gardening", "Books"] do
  {:ok, _} = Hello.Catalog.create_category(%{title: title})
end
```

We simply enumerate over a list of category titles and use the generated `create_category/1` function of our catalog context to persist the new records. We can run the seeds with `mix run`:

```console
$ mix run priv/repo/seeds.exs

[debug] QUERY OK db=3.1ms decode=1.1ms queue=0.7ms idle=2.2ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Home Improvement", ~N[2021-02-03 19:39:53], ~N[2021-02-03 19:39:53]]
[debug] QUERY OK db=1.2ms queue=1.3ms idle=12.3ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Power Tools", ~N[2021-02-03 19:39:53], ~N[2021-02-03 19:39:53]]
[debug] QUERY OK db=1.1ms queue=1.1ms idle=15.1ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Gardening", ~N[2021-02-03 19:39:53], ~N[2021-02-03 19:39:53]]
[debug] QUERY OK db=2.4ms queue=1.0ms idle=17.6ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Books", ~N[2021-02-03 19:39:53], ~N[2021-02-03 19:39:53]]
```

Perfect. Before we integrate categories in the web layer, we need to let our context know how to associate products and categories. First, open up `lib/hello/catalog/product.ex` and add the following association:

```diff
+ alias Hello.Catalog.Category

  schema "products" do
    field :description, :string
    field :price, :decimal
    field :title, :string
    field :views, :integer

+   many_to_many :categories, Category, join_through: "product_categories", on_replace: :delete

    timestamps()
  end

```

We used `Ecto.Schema`'s `many_to_many` macro to let Ecto know how to associate our product to multiple categories through the `"product_categories"` join table. We also used the `on_replace: :delete` option to declare that any existing join records should be deleted when we are changing our categories.

With our schema associations set up, we can implement the selection of categories in our product form. To do so, we need to translate the user input of catalog IDs from the front-end to our many-to-many association. Fortunately Ecto makes this a breeze now that our schema is set up. Open up your catalog context and make the following changes:

```diff
+ alias Hello.Catalog.Category

- def get_product!(id), do: Repo.get!(Product, id)
+ def get_product!(id) do
+   Product |> Repo.get!(id) |> Repo.preload(:categories)
+ end

  def create_product(attrs \\ %{}) do
    %Product{}
-   |> Product.changeset(attrs)
+   |> change_product(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
-   |> Product.changeset(attrs)
+   |> change_product(attrs)
    |> Repo.update()
  end

  def change_product(%Product{} = product, attrs \\ %{}) do
-   Product.changeset(product, attrs)
+   categories = list_categories_by_id(attrs["category_ids"])

+   product
+   |> Repo.preload(:categories)
+   |> Product.changeset(attrs)
+   |> Ecto.Changeset.put_assoc(:categories, categories)
  end

+ def list_categories_by_id(nil), do: []
+ def list_categories_by_id(category_ids) do
+   Repo.all(from c in Category, where: c.id in ^category_ids)
+ end
```

First, we added `Repo.preload` to preload our categories when we fetch a product. This will allow us to reference `product.categories` in our controllers, templates, and anywhere else we want to make use of category information. Next, we modified our `create_product` and `update_product` functions to call into our existing `change_product` function to produce a changeset. Within `change_product` we added a lookup to find all categories if the `"category_ids"` attribute is present. Then we preloaded categories and called `Ecto.Changeset.put_assoc` to place the fetched categories into the changeset. Finally, we implemented the `list_categories_by_id/1` function to query the categories matching the category IDs, or return an empty list if no `"category_ids"` attribute is present. Now our `create_product` and `update_product` functions receive a changeset with the category associations all ready to go once we attempt an insert or update against our repo.

Next, let's expose our new feature to the web by adding the category input to our product form. To keep our form template tidy, let's write a new function to wrap up the details of rendering a category select input for our product. Open up your `ProductHTML` view in `lib/hello_web/controllers/product_html.ex` and key this in:

```elixir
defmodule HelloWeb.ProductHTML do
  use HelloWeb, :html

  import Phoenix.HTML.Form

  def category_select(f, changeset) do
    existing_ids =
      changeset
      |> Ecto.Changeset.get_change(:categories, [])
      |> Enum.map(& &1.data.id)

    category_opts =
      for cat <- Hello.Catalog.list_categories(),
          do: [key: cat.title, value: cat.id, selected: cat.id in existing_ids]

    multiple_select(f, :category_ids, category_opts)
  end
end
```

We added a new `category_select/2` function which uses `Phoenix.HTML.Form`'s `multiple_select/3` to generate a multiple select tag. We calculated the existing category IDs from our changeset, then used those values when we generate the select options for the input tag. We did this by enumerating over all of our categories and returning the appropriate `key`, `value`, and `selected` values. We marked an option as selected if the category ID was found in those category IDs in our changeset.

With our `category_select` function in place, we can open up `lib/hello_web/controllers/product_html/form.html.heex` and add:

```diff
  ...
  <.input type="number" field={f[:views]} label="Views" />

+ <%= category_select f, @changeset %>

  <:actions>
    <.button>Save Product</.button>
  </:actions>
```

We added a `category_select` above our save button. Now let's try it out. Next, let's show the product's categories in the product show template. Add the following code to the list in `lib/hello_web/controllers/product_html/show.html.heex`:

```heex
<.list>
  ...
+ <:item title="Categories">
+   <%= for cat <- @product.categories do %>
+     <%= cat.title %>
+     <br/>
+   <% end %>
+ </:item>
</.list>
```

Now if we start the server with `mix phx.server` and visit [http://localhost:4000/products/new](http://localhost:4000/products/new), we'll see the new category multiple select input. Enter some valid product details, select a category or two, and click save.

```text
Title: Elixir Flashcards
Description: Flash card set for the Elixir programming language
Price: 5.000000
Views: 0
Categories:
Education
Books
```

It's not much to look at yet, but it works! We added relationships within our context complete with data integrity enforced by the database. Not bad. Let's keep building!

## Cross-context dependencies

Now that we have the beginnings of our product catalog features, let's begin to work on the other main features of our application – carting products from the catalog. In order to properly track products that have been added to a user's cart, we'll need a new place to persist this information, along with point-in-time product information like the price at time of carting. This is necessary so we can detect product price changes in the future. We know what we need to build, but now we need to decide where the cart functionality lives in our application.

If we take a step back and think about the isolation of our application, the exhibition of products in our catalog distinctly differs from the responsibilities of managing a user's cart. A product catalog shouldn't care about the rules of our shopping cart system, and vice-versa. There's a clear need here for a separate context to handle the new cart responsibilities. Let's call it `ShoppingCart`.

Let's create a `ShoppingCart` context to handle basic cart duties. Before we write code, let's imagine we have the following feature requirements:

  1. Add products to a user's cart from the product show page
  2. Store point-in-time product price information at time of carting
  3. Store and update quantities in cart
  4. Calculate and display sum of cart prices

From the description, it's clear we need a `Cart` resource for storing the user's cart, along with a `CartItem` to track products in the cart. With our plan set, let's get to work. Run the following command to generate our new context:

```console
$ mix phx.gen.context ShoppingCart Cart carts user_uuid:uuid:unique

* creating lib/hello/shopping_cart/cart.ex
* creating priv/repo/migrations/20210205203128_create_carts.exs
* creating lib/hello/shopping_cart.ex
* injecting lib/hello/shopping_cart.ex
* creating test/hello/shopping_cart_test.exs
* injecting test/hello/shopping_cart_test.exs
* creating test/support/fixtures/shopping_cart_fixtures.ex
* injecting test/support/fixtures/shopping_cart_fixtures.ex

Some of the generated database columns are unique. Please provide
unique implementations for the following fixture function(s) in
test/support/fixtures/shopping_cart_fixtures.ex:

    def unique_cart_user_uuid do
      raise "implement the logic to generate a unique cart user_uuid"
    end

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

We generated our new context `ShoppingCart`, with a new `ShoppingCart.Cart` schema to tie a user to their cart which holds cart items. We don't have real users yet, so for now our cart will be tracked by an anonymous user UUID that we'll add to our plug session in a moment. With our cart in place, let's generate our cart items:

```console
$ mix phx.gen.context ShoppingCart CartItem cart_items \
cart_id:references:carts product_id:references:products \
price_when_carted:decimal quantity:integer

You are generating into an existing context.
...
Would you like to proceed? [Yn] y
* creating lib/hello/shopping_cart/cart_item.ex
* creating priv/repo/migrations/20210205213410_create_cart_items.exs
* injecting lib/hello/shopping_cart.ex
* injecting test/hello/shopping_cart_test.exs
* injecting test/support/fixtures/shopping_cart_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate

```

We generated a new resource inside our `ShoppingCart` named `CartItem`. This schema and table will hold references to a cart and product, along with the price at the time we added the item to our cart, and the quantity the user wishes to purchase. Let's touch up the generated migration file in `priv/repo/migrations/*_create_cart_items.ex`:

```elixir
    create table(:cart_items) do
-     add :price_when_carted, :decimal
+     add :price_when_carted, :decimal, precision: 15, scale: 6, null: false
      add :quantity, :integer
-     add :cart_id, references(:carts, on_delete: :nothing)
+     add :cart_id, references(:carts, on_delete: :delete_all)
-     add :product_id, references(:products, on_delete: :nothing)
+     add :product_id, references(:products, on_delete: :delete_all)

      timestamps()
    end

    create index(:cart_items, [:cart_id])
    create index(:cart_items, [:product_id])
+   create unique_index(:cart_items, [:cart_id, :product_id])
```

We used the `:delete_all` strategy again to enforce data integrity. This way, when a cart or product is deleted from the application, we don't have to rely on application code in our `ShoppingCart` or `Catalog` contexts to worry about cleaning up the records. This keeps our application code decoupled and the data integrity enforcement where it belongs – in the database. We also added a unique constraint to ensure a duplicate product is not allowed to be added to a cart. With our database tables in place, we can now migrate up:

```console
$ mix ecto.migrate

16:59:51.941 [info] == Running 20210205203342 Hello.Repo.Migrations.CreateCarts.change/0 forward

16:59:51.945 [info] create table carts

16:59:51.949 [info] create index carts_user_uuid_index

16:59:51.952 [info] == Migrated 20210205203342 in 0.0s

16:59:51.988 [info] == Running 20210205213410 Hello.Repo.Migrations.CreateCartItems.change/0 forward

16:59:51.988 [info] create table cart_items

16:59:51.998 [info] create index cart_items_cart_id_index

16:59:52.000 [info] create index cart_items_product_id_index

16:59:52.001 [info] create index cart_items_cart_id_product_id_index

16:59:52.002 [info] == Migrated 20210205213410 in 0.0s
```

Our database is ready to go with new `carts` and `cart_items` tables, but now we need to map that back into application code. You may be wondering how we can mix database foreign keys across different tables and how that relates to the context pattern of isolated, grouped functionality. Let's jump in and discuss the approaches and their tradeoffs.

### Cross-context data

So far, we've done a great job isolating the two main contexts of our application from each other, but now we have a necessary dependency to handle.

Our `Catalog.Product` resource serves to keep the responsibilities of representing a product inside the catalog, but ultimately for an item to exist in the cart, a product from the catalog must be present. Given this, our `ShoppingCart` context will have a data dependency on the `Catalog` context. With that in mind, we have two options. One is to expose APIs on the `Catalog` context that allows us to efficiently fetch product data for use in the `ShoppingCart` system, which we would manually stitch together. Or we can use database joins to fetch the dependent data. Both are valid options given your tradeoffs and application size, but joining data from the database when you have a hard data dependency is just fine for a large class of applications and is the approach we will take here.

Now that we know where our data dependencies exist, let's add our schema associations so we can tie shopping cart items to products. First, let's make a quick change to our cart schema in `lib/hello/shopping_cart/cart.ex` to associate a cart to its items:

```elixir
  schema "carts" do
    field :user_uuid, Ecto.UUID

+   has_many :items, Hello.ShoppingCart.CartItem

    timestamps()
  end
```

Now that our cart is associated to the items we place in it, let's set up the cart item associations inside `lib/hello/shopping_cart/cart_item.ex`:

```elixir
  schema "cart_items" do
-   field :cart_id, :id
-   field :product_id, :id
    field :price_when_carted, :decimal
    field :quantity, :integer

+   belongs_to :cart, Hello.ShoppingCart.Cart
+   belongs_to :product, Hello.Catalog.Product

    timestamps()
  end

  @doc false
  def changeset(cart_item, attrs) do
    cart_item
    |> cast(attrs, [:price_when_carted, :quantity])
    |> validate_required([:price_when_carted, :quantity])
+   |> validate_number(:quantity, greater_than_or_equal_to: 0, less_than: 100)
  end
```

First, we replaced the `cart_id` field with a standard `belongs_to` pointing at our `ShoppingCart.Cart` schema. Next, we replaced our `product_id` field by adding our first cross-context data dependency with a `belongs_to` for the `Catalog.Product` schema. Here, we intentionally coupled the data boundaries because it provides exactly what we need. An isolated context API with the bare minimum knowledge necessary to reference a product in our system. Next, we added a new validation to our changeset. With `validate_number/3`, we ensure any quantity provided by user input is between 0 and 100.

With our schemas in place, we can start integrating the new data structures and `ShoppingCart` context APIs into our web-facing features.

### Adding Shopping Cart functions

As we mentioned before, the context generators are only a starting point for our application. We can and should write well-named, purpose built functions to accomplish the goals of our context. We have a few new features to implement. First, we need to ensure every user of our application is granted a cart if one does not yet exist. From there, we can then allow users to add items to their cart, update item quantities, and calculate cart totals. Let's get started!

We won't focus on a real user authentication system at this point, but by the time we're done, you'll be able to naturally integrate one with what we've written here. To simulate a current user session, open up your `lib/hello_web/router.ex` and key this in:

```elixir
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {HelloWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
+   plug :fetch_current_user
+   plug :fetch_current_cart
  end

+ defp fetch_current_user(conn, _) do
+   if user_uuid = get_session(conn, :current_uuid) do
+     assign(conn, :current_uuid, user_uuid)
+   else
+     new_uuid = Ecto.UUID.generate()
+
+     conn
+     |> assign(:current_uuid, new_uuid)
+     |> put_session(:current_uuid, new_uuid)
+   end
+ end

+ alias Hello.ShoppingCart
+
+ def fetch_current_cart(conn, _opts) do
+   if cart = ShoppingCart.get_cart_by_user_uuid(conn.assigns.current_uuid) do
+     assign(conn, :cart, cart)
+   else
+     {:ok, new_cart} = ShoppingCart.create_cart(conn.assigns.current_uuid)
+     assign(conn, :cart, new_cart)
+   end
+ end
```

We added a new `:fetch_current_user` and `:fetch_current_cart` plug to our browser pipeline to run on all browser-based requests. Next, we implemented the `fetch_current_user` plug which simply checks the session for a user UUID that was previously added. If we find one, we add a `current_uuid` assign to the connection and we're done. In the case we haven't yet identified this visitor, we generate a unique UUID with `Ecto.UUID.generate()`, then we place that value in the `current_uuid` assign, along with a new session value to identify this visitor on future requests. A random, unique ID isn't much to represent a user, but it's enough for us to track and identify a visitor across requests, which is all we need for now. Later as our application becomes more complete, you'll be ready to migrate to a complete user authentication solution. With a guaranteed current user, we then implemented the `fetch_current_cart` plug which either finds a cart for the user UUID or creates a cart for the current user and assigns the result in the connection assigns. We'll need to implement our `ShoppingCart.get_cart_by_user_uuid/1` and modify the create cart function to accept a UUID, but let's add our routes first.

We'll need to implement a cart controller for handling cart operations like viewing a cart, updating quantities, and initiating the checkout process, as well as a cart items controller for adding and removing individual items to and from the cart. Add the following routes to your router in `lib/hello_web/router.ex`:

```diff
  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :index
    resources "/products", ProductController

+   resources "/cart_items", CartItemController, only: [:create, :delete]

+   get "/cart", CartController, :show
+   put "/cart", CartController, :update
  end
```

We added a `resources` declaration for a `CartItemController`, which will wire up the routes for a create and delete action for adding and remove individual cart items. Next, we added two new routes pointing at a `CartController`. The first route, a GET request, will map to our show action, to show the cart contents. The second route, a PUT request, will handle the submission of a form for updating our cart quantities.

With our routes in place, let's add the ability to add an item to our cart from the product show page. Create a new file at `lib/hello_web/controllers/cart_item_controller.ex` and key this in:

```elixir
defmodule HelloWeb.CartItemController do
  use HelloWeb, :controller

  alias Hello.{ShoppingCart, Catalog}

  def create(conn, %{"product_id" => product_id}) do
    case ShoppingCart.add_item_to_cart(conn.assigns.cart, product_id) do
      {:ok, _item} ->
        conn
        |> put_flash(:info, "Item added to your cart")
        |> redirect(to: ~p"/cart")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "There was an error adding the item to your cart")
        |> redirect(to: ~p"/cart")
    end
  end

  def delete(conn, %{"id" => product_id}) do
    {:ok, _cart} = ShoppingCart.remove_item_from_cart(conn.assigns.cart, product_id)
    redirect(conn, to: ~p"/cart")
  end
end
```

We defined a new `CartItemController` with the create and delete actions that we declared in our router. For `create`, we call a `ShoppingCart.add_item_to_cart/2` function which we'll implement in a moment. If successful, we show a flash successful message and redirect to the cart show page; else, we show a flash error message and redirect to the cart show page. For `delete`, we'll call a `remove_item_from_cart` function which we'll implement on our `ShoppingCart` context  and then redirect back to the cart show page. We haven't implemented these two shopping cart functions yet, but notice how their names scream their intent: `add_item_to_cart` and `remove_item_from_cart` make it obvious what we are accomplishing here. It also allows us to spec out our web layer and context APIs without thinking about all the implementation details at once.

Let's implement the new interface for the `ShoppingCart` context API in `lib/hello/shopping_cart.ex`:

```elixir
  alias Hello.Catalog
  alias Hello.ShoppingCart.{Cart, CartItem}

  def get_cart_by_user_uuid(user_uuid) do
    Repo.one(
      from(c in Cart,
        where: c.user_uuid == ^user_uuid,
        left_join: i in assoc(c, :items),
        left_join: p in assoc(i, :product),
        order_by: [asc: i.inserted_at],
        preload: [items: {i, product: p}]
      )
    )
  end

- def create_cart(attrs \\ %{}) do
-   %Cart{}
-   |> Cart.changeset(attrs)
+ def create_cart(user_uuid) do
+   %Cart{user_uuid: user_uuid}
+   |> Cart.changeset(%{})
    |> Repo.insert()
+   |> case do
+     {:ok, cart} -> {:ok, reload_cart(cart)}
+     {:error, changeset} -> {:error, changeset}
+   end
  end

  defp reload_cart(%Cart{} = cart), do: get_cart_by_user_uuid(cart.user_uuid)

  def add_item_to_cart(%Cart{} = cart, product_id) do
    product = Catalog.get_product!(product_id)

    %CartItem{quantity: 1, price_when_carted: product.price}
    |> CartItem.changeset(%{})
    |> Ecto.Changeset.put_assoc(:cart, cart)
    |> Ecto.Changeset.put_assoc(:product, product)
    |> Repo.insert(
      on_conflict: [inc: [quantity: 1]],
      conflict_target: [:cart_id, :product_id]
    )
  end

  def remove_item_from_cart(%Cart{} = cart, product_id) do
    {1, _} =
      Repo.delete_all(
        from(i in CartItem,
          where: i.cart_id == ^cart.id,
          where: i.product_id == ^product_id
        )
      )

    {:ok, reload_cart(cart)}
  end
```

We started by implementing  `get_cart_by_user_uuid/1` which fetches our cart and joins the cart items, and their products so that we have the full cart populated with all preloaded data. Next, we modified our `create_cart` function to accept a user UUID instead of attributes, which we used to populate the `user_uuid` field. If the insert is successful, we reload the cart contents by calling a private `reload_cart/1` function, which simply calls `get_cart_by_user_uuid/1` to refetch data.

Next, we wrote our new `add_item_to_cart/2` function which accepts a cart struct and a product id. We proceed to fetch the product with `Catalog.get_product!/1`, showing how contexts can naturally invoke other contexts if required. You could also have chosen to receive the product as argument and you would achieve similar results. Then we used an upsert operation against our repo to either insert a new cart item into the database, or increase the quantity by one if it already exists in the cart. This is accomplished via the `on_conflict` and `conflict_target` options, which tells our repo how to handle an insert conflict.

Finally, we implemented `remove_item_from_cart/2` where we simply issue a `Repo.delete_all` call with a query to delete the cart item in our cart that matches the product ID. Finally, we reload the cart contents by calling `reload_cart/1`.

With our new cart functions in place, we can now expose the "Add to cart" button on the product catalog show page. Open up your template in `lib/hello_web/controllers/product_html/show.html.heex` and make the following changes:

```diff
<h1>Show Product</h1>

+<.link href={~p"/cart_items?product_id=#{@product.id}"} method="post">Add to cart</.link>
...
```

The `link` function component from `Phoenix.Component` accepts a `:method` attribute to issue an HTTP verb when clicked, instead of the default GET request. With this link in place, the "Add to cart" link will issue a POST request, which will be matched by the route we defined in router which dispatches to the `CartItemController.create/2` function.

Let's try it out. Start your server with `mix phx.server` and visit a product page. If we try clicking the add to cart link, we'll be greeted by an error page with the following logs in the console:

```text
[info] POST /cart_items
[debug] Processing with HelloWeb.CartItemController.create/2
  Parameters: %{"_method" => "post", "product_id" => "1", ...}
  Pipelines: [:browser]
INSERT INTO "cart_items" ...
[info] Sent 302 in 24ms
[info] GET /cart
[debug] Processing with HelloWeb.CartController.show/2
  Parameters: %{}
  Pipelines: [:browser]
[debug] QUERY OK source="carts" db=1.9ms idle=1798.5ms

[error] #PID<0.856.0> running HelloWeb.Endpoint (connection #PID<0.841.0>, stream id 5) terminated
Server: localhost:4000 (http)
Request: GET /cart
** (exit) an exception was raised:
    ** (UndefinedFunctionError) function HelloWeb.CartController.init/1 is undefined
       (module HelloWeb.CartController is not available)
       ...
```

It's working! Kind of. If we follow the logs, we see our POST to the `/cart_items` path. Next, we can see our `ShoppingCart.add_item_to_cart` function successfully inserted a row into the `cart_items` table, and then we issued a redirect to `/cart`. Before our error, we also see a query to the `carts` table, which means we're fetching the current user's cart. So far so good. We know our `CartItem` controller and new `ShoppingCart` context functions are doing their jobs, but we've hit our next unimplemented feature when the router attempts to dispatch to a nonexistent cart controller. Let's create the cart controller, view, and template to display and manage user carts.

Create a new file at `lib/hello_web/controllers/cart_controller.ex` and key this in:

```elixir
defmodule HelloWeb.CartController do
  use HelloWeb, :controller

  alias Hello.ShoppingCart

  def show(conn, _params) do
    render(conn, :show, changeset: ShoppingCart.change_cart(conn.assigns.cart))
  end
end
```

We defined a new cart controller to handle the `get "/cart"` route. For showing a cart, we render a `"show.html"` template which we'll create in moment. We know we need to allow the cart items to be changed by quantity updates, so right away we know we'll need a cart changeset. Fortunately, the context generator included a `ShoppingChart.change_cart/1` function, which we'll use. We pass it our cart struct which is already in the connection assigns thanks to the `fetch_current_cart` plug we defined in the router.

Next, we can implement the view and template. Create a new view file at `lib/hello_web/controllers/cart_html.ex` with the following content:

```elixir
defmodule HelloWeb.CartHTML do
  use HelloWeb, :html

  alias Hello.ShoppingCart

  import Phoenix.HTML.Form

  embed_templates "cart_html/*"

  def currency_to_str(%Decimal{} = val), do: "$#{Decimal.round(val, 2)}"
end
```

We created a view to render our `show.html` template and aliased our `ShoppingCart` context so it will be in scope for our template. We'll need to display the cart prices like product item price, cart total, etc, so we defined a `currency_to_str/1` which takes our decimal struct, rounds it properly for display, and prepends a USD dollar sign.

Next we can create the template at `lib/hello_web/controllers/cart_html/show.html.heex`:

```heex
<h1>My Cart</h1>

<%= if @cart.items == [] do %>
  Your cart is empty
<% else %>
  <.form :let={f} for={@changeset} action={~p"/cart"}>
    <ul>
      <%= for item_form <- inputs_for(f, :items), item = item_form.data do %>
        <li>
          <%= hidden_inputs_for(item_form) %>
          <%= item.product.title %>
          <%= number_input item_form, :quantity %>
          <%= currency_to_str(ShoppingCart.total_item_price(item)) %>
        </li>
      <% end %>
    </ul>

    <%= submit "update cart" %>
  </.form>

  <b>Total</b>: <%= currency_to_str(ShoppingCart.total_cart_price(@cart)) %>
<% end %>
```

We started by showing the empty cart message if our preloaded `cart.items` is empty. If we have items, we use the [`form`] component provided by (`Phoenix.Component`) to take our cart changeset that we assigned in the `CartController.show/2` action and create a form which maps to our cart controller `update/2` action. Within the form, we use `Phoenix.HTML.Form.inputs_for/2` to render inputs for the nested cart items. For each item form input, we use [`hidden_inputs_for/1`](`Phoenix.HTML.Form.hidden_inputs_for/1`) which will render out the item ID as a hidden input tag. This will allow us to map item inputs back together when the form is submitted. Next, we display the product title for the item in the cart, followed by a number input for the item quantity. We finish the item form by converting the item price to string. We haven't written the `ShoppingCart.total_item_price/1` function yet, but again we employed the idea of clear, descriptive public interfaces for our contexts. After rendering inputs for all the cart items, we show an "update cart" submit button, along with the total price of the entire cart. This is accomplished with another new `ShoppingCart.total_cart_price/1` function which we'll implement in a moment.

We're almost ready to try out our cart page, but first we need to implement our new currency calculation functions. Open up your shopping cart context at `lib/hello/shopping_cart.ex` and add these new functions:

```elixir
  def total_item_price(%CartItem{} = item) do
    Decimal.mult(item.product.price, item.quantity)
  end

  def total_cart_price(%Cart{} = cart) do
    Enum.reduce(cart.items, 0, fn item, acc ->
      item
      |> total_item_price()
      |> Decimal.add(acc)
    end)
  end
```

We implemented `total_item_price/1` which accepts a `%CartItem{}` struct. To calculate the total price, we simply take the preloaded product's price and multiply it by the item's quantity. We used `Decimal.mult/2` to take our decimal currency struct and multiply it with proper precision. Similarly for calculating the total cart price, we implemented a `total_cart_price/1` function which accepts the cart and sums the preloaded product prices for items in the cart. We again make use of the `Decimal` functions to add our decimal structs together.

Now that we can calculate price totals, let's try it out! Visit [`http://localhost:4000/cart`](http://localhost:4000/cart) and you should already see your first item in the cart. Going back to the same product and clicking "add to cart" will show our upsert in action. Your quantity should now be two. Nice work!

Our cart page is almost complete, but submitting the form will yield yet another error.

```text
Request: POST /cart
** (exit) an exception was raised:
    ** (UndefinedFunctionError) function HelloWeb.CartController.update/2 is undefined or private
```

Let's head back to our `CartController` at `lib/hello_web/controllers/cart_controller.ex` and implement the update action:

```elixir
  def update(conn, %{"cart" => cart_params}) do
    case ShoppingCart.update_cart(conn.assigns.cart, cart_params) do
      {:ok, _cart} ->
        redirect(conn, to: ~p"/cart")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "There was an error updating your cart")
        |> redirect(to: ~p"/cart")
    end
  end
```

We started by plucking out the cart params from the form submit. Next, we call our existing `ShoppingCart.update_cart/2` function which was added by the context generator. We'll need to make some changes to this function, but the interface is good as is. If the update is successful, we redirect back to the cart page, otherwise we show a flash error message and send the user back to the cart page to fix any mistakes. Out-of-the-box, our `ShoppingCart.update_cart/2` function only concerned itself with casting the cart params into a changeset and updates it against our repo. For our purposes, we now need it to handle nested cart item associations, and most importantly, business logic for how to handle quantity updates like zero-quantity items being removed from the cart.

Head back over to your shopping cart context in `lib/hello/shopping_cart.ex` and replace your `update_cart/2` function with the following implementation:

```elixir
  def update_cart(%Cart{} = cart, attrs) do
    changeset =
      cart
      |> Cart.changeset(attrs)
      |> Ecto.Changeset.cast_assoc(:items, with: &CartItem.changeset/2)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:cart, changeset)
    |> Ecto.Multi.delete_all(:discarded_items, fn %{cart: cart} ->
      from(i in CartItem, where: i.cart_id == ^cart.id and i.quantity == 0)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{cart: cart}} -> {:ok, cart}
      {:error, :cart, changeset, _changes_so_far} -> {:error, changeset}
    end
  end
```

We started much like how our out-of-the-box code started – we take the cart struct and cast the user input to a cart changeset, except this time we use `Ecto.Changeset.cast_assoc/3` to cast the nested item data into `CartItem` changesets. Remember the [`hidden_inputs_for/1`](`Phoenix.HTML.Form.hidden_inputs_for/1`) call in our cart form template? That hidden ID data is what allows Ecto's `cast_assoc` to map item data back to existing item associations in the cart. Next we use `Ecto.Multi.new/0`, which you may not have seen before. Ecto's `Multi` is a feature that allows lazily defining a chain of named operations to eventually execute inside a database transaction. Each operation in the multi chain receives the values from the previous steps and executes until a failed step is encountered. When an operation fails, the transaction is rolled back and an error is returned, otherwise the transaction is committed.

For our multi operations, we start by issuing an update of our cart, which we named `:cart`. After the cart update is issued, we perform a multi `delete_all` operation, which takes the updated cart and applies our zero-quantity logic. We prune any items in the cart with zero quantity by returning an ecto query that finds all cart items for this cart with an empty quantity. Calling `Repo.transaction/1` with our multi will execute the operations in a new transaction and we return the success or failure result to the caller just like the original function.

Let's head back to the browser and try it out. Add a few products to your cart, update the quantities, and watch the values changes along with the price calculations. Setting any quantity to 0 will also remove the item. Pretty neat!

## Adding an Orders context

With our `Catalog` and `ShoppingCart` contexts, we're seeing first-hand how our well-considered modules and function names are yielding clear and maintainable code. Our last order of business is to allow the user to initiate the checkout process. We won't go as far as integrating payment processing or order fulfillment, but we'll get you started in that direction. Like before, we need to decide where code for completing an order should live. Is it part of the catalog? Clearly not, but what about the shopping cart? Shopping carts are related to orders – after all the user has to add items in order to purchase any products, but should the order checkout process be grouped here?

If we stop and consider the order process, we'll see that orders involve related, but distinctly different data from the cart contents. Also, business rules around the checkout process are much different than carting. For example, we may allow a user to add a back-ordered item to their cart, but we could not allow an order with no inventory to be completed. Additionally, we need to capture point-in-time product information when an order is completed, such as the price of the items *at payment transaction time*. This is essential because a product price may change in the future, but the line items in our order must always record and display what we charged at time of purchase. For these reasons, we can start to see ordering can reasonably stand on its own with its own data concerns and business rules.

Naming wise, `Orders` clearly defines the scope of our context, so let's get started by again taking advantage of the context generators. Run the following command in your console:

```console
$ mix phx.gen.html Orders Order orders user_uuid:uuid total_price:decimal

* creating lib/hello_web/controllers/order_controller.ex
* creating lib/hello_web/controllers/order_html/edit.html.heex
* creating lib/hello_web/controllers/order_html/form.html.heex
* creating lib/hello_web/controllers/order_html/index.html.heex
* creating lib/hello_web/controllers/order_html/new.html.heex
* creating lib/hello_web/controllers/order_html/show.html.heex
* creating lib/hello_web/controllers/order_html.ex
* creating test/hello_web/controllers/order_controller_test.exs
* creating lib/hello/orders/order.ex
* creating priv/repo/migrations/20210209214612_create_orders.exs
* creating lib/hello/orders.ex
* injecting lib/hello/orders.ex
* creating test/hello/orders_test.exs
* injecting test/hello/orders_test.exs
* creating test/support/fixtures/orders_fixtures.ex
* injecting test/support/fixtures/orders_fixtures.ex

Add the resource to your browser scope in lib/hello_web/router.ex:

    resources "/orders", OrderController


Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

We generated a `Orders` context along with HTML controllers, views, etc. We added a `user_uuid` field to associate our placeholder current user to an order, along with a `total_price` column. With our starting point in place, let's open up the newly created migration in `priv/repo/migrations/*_create_orders.exs` and make the following changes:

```elixir
  def change do
    create table(:orders) do
      add :user_uuid, :uuid
-     add :total_price, :decimal
+     add :total_price, :decimal, precision: 15, scale: 6, null: false

      timestamps()
    end
  end
```

Like we did previously, we gave appropriate precision and scale options for our decimal column which will allow us to store currency without precision loss. We also added a not-null constraint to enforce all orders to have a price.

The orders table alone doesn't hold much information, but we know we'll need to store point-in-time product price information of all the items in the order. For that, we'll add an additional struct for this context named `LineItem`. Line items will capture the price of the product *at payment transaction time*. Please run the following command:

```console
$ mix phx.gen.context Orders LineItem order_line_items \
price:decimal quantity:integer \
order_id:references:orders product_id:references:products

You are generating into an existing context.
Would you like to proceed? [Yn] y
* creating lib/hello/orders/line_item.ex
* creating priv/repo/migrations/20210209215050_create_order_line_items.exs
* injecting lib/hello/orders.ex
* injecting test/hello/orders_test.exs
* injecting test/support/fixtures/orders_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

We used the `phx.gen.context` command to generate the `LineItem` Ecto schema and inject supporting functions into our orders context. Like before, let's modify the migration in `priv/repo/migrations/*_create_order_line_items.exs` and make the following decimal field changes:

```elixir
  def change do
    create table(:order_line_items) do
-     add :price, :decimal
+     add :price, :decimal, precision: 15, scale: 6, null: false
      add :quantity, :integer
      add :order_id, references(:orders, on_delete: :nothing)
      add :product_id, references(:products, on_delete: :nothing)

      timestamps()
    end

    create index(:order_line_items, [:order_id])
    create index(:order_line_items, [:product_id])
  end
```

With our migration in place, let's wire up our orders and line items associations in `lib/hello/orders/order.ex`:

```elixir
  schema "orders" do
    field :total_price, :decimal
    field :user_uuid, Ecto.UUID

+   has_many :line_items, Hello.Orders.LineItem
+   has_many :products, through: [:line_items, :product]

    timestamps()
  end
```

We used `has_many :line_items` to associate orders and line items, just like we've seen before. Next, we used the `:through` feature of `has_many`, which allows us to instruct ecto how to associate resources across another relationship. In this case, we can associate products of an order by finding all products through associated line items. Next, let's wire up the association in the other direction in `lib/hello/orders/line_item.ex`:

```elixir
  schema "order_line_items" do
    field :price, :decimal
    field :quantity, :integer
-   field :order_id, :id
-   field :product_id, :id

+   belongs_to :order, Hello.Orders.Order
+   belongs_to :product, Hello.Catalog.Product

    timestamps()
  end
```

We used `belongs_to` to associate line items to orders and products. With our associations in place, we can start integrating the web interface into our order process. Open up your router `lib/hello_web/router.ex` and add the following line:

```elixir
  scope "/", HelloWeb do
    pipe_through :browser

    ...
+   resources "/orders", OrderController, only: [:create, :show]
  end
```

We wired up `create` and `show` routes for our generated `OrderController`, since these are the only actions we need at the moment. With our routes in place, we can now migrate up:

```console
$ mix ecto.migrate

17:14:37.715 [info] == Running 20210209214612 Hello.Repo.Migrations.CreateOrders.change/0 forward

17:14:37.720 [info] create table orders

17:14:37.755 [info] == Migrated 20210209214612 in 0.0s

17:14:37.784 [info] == Running 20210209215050 Hello.Repo.Migrations.CreateOrderLineItems.change/0 forward

17:14:37.785 [info] create table order_line_items

17:14:37.795 [info] create index order_line_items_order_id_index

17:14:37.796 [info] create index order_line_items_product_id_index

17:14:37.798 [info] == Migrated 20210209215050 in 0.0s
```

Before we render information about our orders, we need to ensure our order data is fully populated and can be looked up by a current user. Open up your orders context in `lib/hello/orders.ex` and replace your `get_order!/1` function by a new `get_order!/2` definition:

```elixir
  def get_order!(user_uuid, id) do
    Order
    |> Repo.get_by!(id: id, user_uuid: user_uuid)
    |> Repo.preload([line_items: [:product]])
  end
```

We rewrote the function to accept a user UUID and query our repo for an order matching the user's ID for a given order ID. Then we populated the order by preloading our line item and product associations.

To complete an order, our cart page can issue a POST to the `OrderController.create` action, but we need to implement the operations and logic to actually complete an order. Like before, we'll start at the web interface by rewriting the create function in `lib/hello_web/controllers/order_controller.ex`:

```elixir
  def create(conn, _) do
    case Orders.complete_order(conn.assigns.cart) do
      {:ok, order} ->
        conn
        |> put_flash(:info, "Order created successfully.")
        |> redirect(to: ~p"/orders/#{order}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "There was an error processing your order")
        |> redirect(to: ~p"/cart")
    end
  end
```

We rewrote the `create` action to call an as-yet-implemented `Orders.complete_order/1` function. The code that phoenix generated had a generic `Orders.create_order/1` call. Our code is technically "creating" an order, but it's important to step back and consider the naming of your interfaces. The act of *completing* an order is extremely important in our system. Money changes hands in a transaction, physical goods could be automatically shipped, etc. Such an operation deserves a better, more obvious function name, such as `complete_order`. If the order is completed successfully we redirect to the show page, otherwise a flash error is shown as we redirect back to the cart page.

Here is also a good opportunity to highlight that contexts can naturally work with data defined by other contexts too. This will be specially common with data that is used throughout the application, such as the cart here (but it can also be the current user or the current project, and so forth, depending on your project).

Now we can implement our `Orders.complete_order/1` function. To complete an order, our job will require a few operations:

  1. A new order record must be persisted with the total price of the order
  2. All items in the cart must be transformed into new order line items records
    with quantity and point-in-time product price information
  3. After successful order insert (and eventual payment), items must be pruned
    from the cart

From our requirements alone, we can start to see why a generic `create_order` function doesn't cut it. Let's implement this new function in `lib/hello/orders.ex`:

```elixir
  alias Hello.ShoppingCart
  alias Hello.Orders.LineItem

  def complete_order(%ShoppingCart.Cart{} = cart) do
    line_items =
      Enum.map(cart.items, fn item ->
        %{product_id: item.product_id, price: item.product.price, quantity: item.quantity}
      end)

    order =
      Ecto.Changeset.change(%Order{},
        user_uuid: cart.user_uuid,
        total_price: ShoppingCart.total_cart_price(cart),
        line_items: line_items
      )

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:order, order)
    |> Ecto.Multi.run(:prune_cart, fn _repo, _changes ->
      ShoppingCart.prune_cart_items(cart)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{order: order}} -> {:ok, order}
      {:error, name, value, _changes_so_far} -> {:error, {name, value}}
    end
  end
```

We started by mapping the `%ShoppingCart.CartItem{}`'s in our shopping cart into a map of order line items structs. The job of the order line item record is to capture the price of the product *at payment transaction time*, so we reference the product's price here. Next, we create a bare order changeset with `Ecto.Changeset.change/2` and associate our user UUID, set our total price calculation, and place our order line items in the changeset. With a fresh order changeset ready to be inserted, we can again make use of `Ecto.Multi` to execute our operations in a database transaction. We start by inserting the order, followed by a `run` operation. The `Ecto.Multi.run/3` function allows us to run any code in the function which must either succeed with `{:ok, result}` or error, which halts and rolls back the transaction. Here, we simply can call into our shopping cart context and ask it to prune all items in a cart. Running the transaction will execute the multi as before and we return the result to the caller.

To close out our order completion, we need to implement the `ShoppingCart.prune_cart_items/1` function in `lib/hello/shopping_cart.ex`:

```elixir
  def prune_cart_items(%Cart{} = cart) do
    {_, _} = Repo.delete_all(from(i in CartItem, where: i.cart_id == ^cart.id))
    {:ok, reload_cart(cart)}
  end
```

Our new function accepts the cart struct and issues a `Repo.delete_all` which accepts a query of all items for the provided cart. We return a success result by simply reloading the pruned cart to the caller. With our context complete, we now need to show the user their completed order. Head back to your order controller and modify the `show/2` action:

```elixir
  def show(conn, %{"id" => id}) do
-   order = Orders.get_order!(id)
+   order = Orders.get_order!(conn.assigns.current_uuid, id)
    render(conn, :show, order: order)
  end
```

We tweaked the show action to pass our `conn.assigns.current_uuid` to `get_order!` which authorizes orders to be viewable only by the owner of the order. Next, we can replace the order show template in `lib/hello_web/controllers/order_html/show.html.heex`:

```heex
<h1>Thank you for your order!</h1>

<ul>
  <li>
    <strong>User uuid:</strong>
    <%= @order.user_uuid %>
  </li>

  <li :for={item <- @order.line_items}>
    <%= item.product.title %>
    (<%= item.quantity %>) - <%= HelloWeb.CartHTML.currency_to_str(item.price) %>
  </li>

  <li>
    <strong>Total price:</strong>
    <%= HelloWeb.CartHTML.currency_to_str(@order.total_price) %>
  </li>

</ul>

<span><.link href={~p"/cart"}>Back</.link></span>
```

To show our completed order, we displayed the order's user, followed by the line item listing with product title, quantity, and the price we "transacted" when completing the order, along with the total price.

Our last addition will be to add the "complete order" button to our cart page to allow completing an order. Add the following button to the bottom of the cart show template in `lib/hello_web/controllers/cart_html/show.html.heex`:

```diff
  <b>Total</b>: <%= currency_to_str(ShoppingCart.total_cart_price(@cart)) %>

+ <.link href={~p"/orders"} method="post">complete order</.link>
<% end %>
```

We added a link with `method="post"` to send a POST request to our `OrderController.create` action. If we head back to our cart page at [`http://localhost:4000/cart`](http://localhost:4000/cart) and complete an order, we'll be greeted by our rendered template:

```text
Thank you for your order!

User uuid: 08964c7c-908c-4a55-bcd3-9811ad8b0b9d
Metaprogramming Elixir (2) - $15.00
Total price: $30.00
```

Nice work! We haven't added payments, but we can already see how our `ShoppingCart` and `Orders` context splitting is driving us towards a maintainable solution. With our cart items separated from our order line items, we are well equipped in the future to add payment transactions, cart price detection, and more.

Great work!

## FAQ

### Returning Ecto structures from context APIs

As we explored the context API, you might have wondered:

> If one of the goals of our context is to encapsulate Ecto Repo access, why does `create_user/1` return an `Ecto.Changeset` struct when we fail to create a user?

Although Changesets are part of Ecto, they are not tied to the database, and they can be used to map data from and to any source, which makes it a general and useful data structure for tracking field changes, perform validations, and generate error messages.

For those reasons, `%Ecto.Changeset{}` is a good choice to model the data changes between your contexts and your web layer. Regardless if you are talking to an API or the database.

Finally, note that your controllers and views are not hardcoded to work exclusively with Ecto either. Instead, Phoenix defines protocols such as `Phoenix.Param` and `Phoenix.HTML.FormData`, which allow any library to extend how Phoenix generates URL parameters or renders forms. Conveniently for us, the `phoenix_ecto` project implements those protocols, but you could as well bring your own data structures and implement them yourself.
