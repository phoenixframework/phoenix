# 2. Your First Context

An ecommerce platform has wide-reaching coupling across a codebase so it's important to think about writing well-defined modules. With that in mind, our goal is to build a product catalog API that handles creating, updating, and deleting the products available in our system. We'll start off with the basic features of showcasing our products, and we will add shopping cart features later. We'll see how starting with a solid foundation with isolated boundaries allows us to grow our application naturally as we add functionality.

Phoenix includes the `mix phx.gen.html`, `mix phx.gen.json`, `mix phx.gen.live`, and `mix phx.gen.context` generators that apply the ideas of isolating functionality in our applications into contexts. These generators are a great way to hit the ground running while Phoenix nudges you in the right direction to grow your application. Let's put these tools to use for our new product catalog context.

When we run the generators, the context name is optional, and Phoenix will automatically use the plural name as the context module. This allows us to keep moving forward when starting out or when it is not yet clear how the different parts of our system relate to each other. Luckily, the needs of ecommerce systems are well defined nowadays, so it provides an excellent ground for us to design with intent. So let's take a step back and think about the different parts of our system.

We know that we'll have products to showcase on pages for sale, along with descriptions, pricing, etc. Along with selling products, we know we'll need to support carting, order checkout, and so on. While the products being purchased are related to the cart and checkout processes, showcasing a product and managing the *exhibition* of our products is distinctly different than tracking what a user has placed in their cart or how an order is placed. A `Catalog` context is a natural place for the management of our product details and the showcasing of those products we have for sale.

## Starting with generators

To jump-start our catalog context, we'll use `mix phx.gen.html` which creates a context module that wraps up Ecto access for creating, updating, and deleting products, along with web files like controllers and templates for the web interface into our context. Run the following command at your project root:

```console
$ mix phx.gen.html Catalog Product products title:string \
description:string price:decimal views:integer
```
After executing the command, you should see output similar to the following:

```console
* creating lib/hello_web/controllers/product_controller.ex
* creating lib/hello_web/controllers/product_html/edit.html.heex
* creating lib/hello_web/controllers/product_html/index.html.heex
* creating lib/hello_web/controllers/product_html/new.html.heex
* creating lib/hello_web/controllers/product_html/show.html.heex
* creating lib/hello_web/controllers/product_html/product_form.html.heex
* creating lib/hello_web/controllers/product_html.ex
* creating test/hello_web/controllers/product_controller_test.exs
* creating lib/hello/catalog/product.ex
* creating priv/repo/migrations/20250201185747_create_products.exs
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

Phoenix generated the web files as expected in `lib/hello_web/`. We can also see our context functions were generated inside a `lib/hello/catalog.ex` file and our product schema file is placed in the directory of the same name. Note the difference between `lib/hello` and `lib/hello_web`. We have a `Catalog` module to serve as the public API for product catalog functionality, as well as a `Catalog.Product` struct, which is an Ecto schema for casting and validating product data. Phoenix also provided web and context tests for us, it also included test helpers for creating entities via the `Hello.Catalog` context, which we'll look at later. For now, let's follow the instructions and add the route according to the console instructions, in `lib/hello_web/router.ex`:

```diff
  scope "/", HelloWeb do
    pipe_through :browser

    get "/", PageController, :index
+   resources "/products", ProductController
  end
```

With the new route in place, Phoenix reminds us to update our repo by running `mix ecto.migrate`, but first we need to make a few tweaks to the generated migration in `priv/repo/migrations/*_create_products.exs`:

```diff
  def change do
    create table(:products) do
      add :title, :string
      add :description, :string
-     add :price, :decimal
+     add :price, :decimal, precision: 15, scale: 6, null: false
-     add :views, :integer
+     add :views, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end
```

We modified our price column to a specific precision of 15, scale of 6, along with a not-null constraint. This ensures we store currency with proper precision for any mathematical operations we may perform. Next, we added a default value and not-null constraint to our views count. With our changes in place, we're ready to migrate up our database. Let's do that now:

```console
$ mix ecto.migrate
14:09:02.260 [info] == Running 20250201185747 Hello.Repo.Migrations.CreateProducts.change/0 forward

14:09:02.262 [info] create table products

14:09:02.273 [info] == Migrated 20250201185747 in 0.0s
```

Before we jump into the generated code, let's start the server with `mix phx.server` and visit [http://localhost:4000/products](http://localhost:4000/products). Let's follow the "New Product" link and click the "Save" button without providing any input. When we submit the form, we can see all the validation errors inline with the inputs. Nice! Out of the box, the context generator included the schema fields in our form template and we can see our default validations for required inputs are in effect. Let's enter some example product data and resubmit the form:

```text
Product created successfully.

Title: Metaprogramming Elixir
Description: Write Less Code, Get More Done (and Have Fun!)
Price: 15.000000
Views: 0
```

If we follow the "Back" link, we get a list of all products, which should contain the one we just created. Likewise, we can update this record or delete it. Now that we've seen how it works in the browser, it's time to take a look at the generated code.

> #### Naming things is hard {: .tip}
>
> When starting a web application, it may be hard to draw lines or name its different contexts, especially when the business domain you are working with is not as well established as ecommerce.
>
> For those reasons, Phoenix generators allow you to skip the context name, which is really helpful when you're stuck or still exploring your business domain. For example, our code above would work the same if we used the default `Products` context for managing products and it would still allow us to organically discover other resources that belong to the `Products` context, such as categories or image galleries.
>
> We also advise against being too smart when naming your contexts. Pick a name that is clear and obvious to everyone who works (and might work) in the project. As your application grows and the different parts of your system become clear, you can simply rename the context or move resources around. The beauty of Elixir modules is moving them around should be simply a matter of renaming the module names and their callers (and renaming the files for consistency).

## Grokking generated code

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

This module will be the public API for all product catalog functionality in our system. For example, in addition to product detail management, we may also handle product category classification and product variants for things like optional sizing, trims, etc. If we look at the `list_products/0` function, we can see the private details of product fetching. And it's super simple. We have a call to `Repo.all(Product)`. We saw how Ecto repo queries worked in the [Ecto guide](ecto.html), so this call should look familiar. Our `list_products` function is a generalized function name specifying the *intent* of our code – namely to list products. The details of that intent where we use our Repo to fetch the products from our PostgreSQL database, are hidden from our callers. This is a common theme we'll see reiterated as we use the Phoenix generators. Phoenix will push us to think about where we have different responsibilities in our application, and then to wrap up those different areas behind well-named modules and functions that make the intent of our code clear, while encapsulating the details.

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
  def create_product(attrs) do
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

    timestamps(type: :utc_datetime)
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

As we've seen, designing with contexts gives you a solid foundation to grow your application from. Using discrete, well-defined APIs that expose the intent of your system allows you to write more maintainable applications with reusable code. Now that we know how to start extending our context API, let's explore handling relationships within a context.
