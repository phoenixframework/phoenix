# 3. In-context Relationships

Our basic catalog features are nice, but let's take it up a notch by categorizing products. Many ecommerce solutions allow products to be categorized in different ways, such as a product being marked for fashion, power tools, and so on. Starting with a one-to-one relationship between product and categories will cause major code changes later if we need to start supporting multiple categories. Let's set up a category association that will allow us to start off tracking a single category per product, but easily support more later as we grow our features.

For now, categories will contain only textual information. Our first order of business is to decide where categories live in the application. We have our `Catalog` context, which manages the exhibition of our products. Product categorization is a natural fit here. Phoenix is also smart enough to generate code inside an existing context, which makes adding new resources to a context a breeze. Run the following command at your project root:

> Sometimes it may be tricky to determine if two resources belong to the same context or not. In those cases, prefer distinct contexts per resource and refactor later if necessary. Otherwise you can easily end up with large contexts of loosely related entities. Also keep in mind that the fact two resources are related does not necessarily mean they belong to the same context, otherwise you would quickly end up with one large context, as the majority of resources in an application are connected to each other. To sum it up: if you are unsure, you should prefer separate modules (contexts).

```console
mix phx.gen.context Catalog Category categories \
title:string:unique --no-scope
```

You will see the following output in your terminal: 

```console
You are generating into an existing context.

The Hello.Catalog context currently has 7 functions and 1 file in its directory.

  * It's OK to have multiple resources in the same context as long as they are closely related. 

...

Would you like to proceed? [Yn]
```

Type `y` followed by the `Return` key.
You should see output similar to:

```console
* creating lib/hello/catalog/category.ex
* creating priv/repo/migrations/20250203192325_create_categories.exs
* injecting lib/hello/catalog.ex
* injecting test/hello/catalog_test.exs
* injecting test/support/fixtures/catalog_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

This time around, we used `mix phx.gen.context`, which is just like `mix phx.gen.html`, except it doesn't generate the web files for us. Since we already have controllers and templates for managing products, we can integrate the new category features into our existing web form and product show page. We can see we now have a new `Category` schema alongside our product schema at `lib/hello/catalog/category.ex`, and Phoenix told us it was *injecting* new functions in our existing Catalog context for the category functionality. The injected functions will look very familiar to our product functions, with new functions like `create_category`, `list_categories`, and so on. Before we migrate up, we need to do a second bit of code generation. Our category schema is great for representing an individual category in the system, but we need to support a many-to-many relationship between products and categories. Fortunately, ecto allows us to do this simply with a join table, so let's generate that now with the `ecto.gen.migration` command:

```console
mix ecto.gen.migration create_product_categories
```

You will see output confirming the migration file was created:

```console
* creating priv/repo/migrations/20250203192958_create_product_categories.exs
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
mix ecto.migrate
```

You will see the following output confirming migration success:

```
18:20:36.489 [info] == Running 20250222231834 Hello.Repo.Migrations.CreateCategories.change/0 forward

18:20:36.493 [info] create table categories

18:20:36.508 [info] create index categories_title_index

18:20:36.512 [info] == Migrated 20250222231834 in 0.0s

18:20:36.547 [info] == Running 20250222231930 Hello.Repo.Migrations.CreateProductCategories.change/0 forward

18:20:36.547 [info] create table product_categories

18:20:36.557 [info] create index product_categories_product_id_index

18:20:36.560 [info]  create index product_categories_category_id_product_id_index

18:20:36.562 [info] == Migrated 20250222231930 in 0.0s
```

Now that we have a `Catalog.Product` schema and a join table to associate products and categories, we're nearly ready to start wiring up our new features. Before we dive in, we first need real categories to select in our web UI. Let's quickly seed some new categories in the application. Add the following code to your seeds file in `priv/repo/seeds.exs`:

```elixir
for title <- ["Home Improvement", "Power Tools", "Gardening", "Books", "Education"] do
  {:ok, _} = Hello.Catalog.create_category(%{title: title})
end
```

We simply enumerate over a list of category titles and use the generated `create_category/1` function of our catalog context to persist the new records. We can run the seeds with `mix run`:

```console
mix run priv/repo/seeds.exs
```

The output in the terminal confirms the `seeds.exs` executed successfully: 

```console
[debug] QUERY OK db=3.1ms decode=1.1ms queue=0.7ms idle=2.2ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Home Improvement", ~N[2025-02-03 19:39:53], ~N[2025-02-03 19:39:53]]
[debug] QUERY OK db=1.2ms queue=1.3ms idle=12.3ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Power Tools", ~N[2025-02-03 19:39:53], ~N[2025-02-03 19:39:53]]
[debug] QUERY OK db=1.1ms queue=1.1ms idle=15.1ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Gardening", ~N[2025-02-03 19:39:53], ~N[2025-02-03 19:39:53]]
[debug] QUERY OK db=2.4ms queue=1.0ms idle=17.6ms
INSERT INTO "categories" ("title","inserted_at","updated_at") VALUES ($1,$2,$3) RETURNING "id" ["Books", ~N[2025-02-03 19:39:53], ~N[2025-02-03 19:39:53]]
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

    timestamps(type: :utc_datetime)
  end

```

We used `Ecto.Schema`'s `many_to_many` macro to let Ecto know how to associate our product to multiple categories through the `"product_categories"` join table. We also used the `on_replace: :delete` option to declare that any existing join records should be deleted when we are changing our categories.

With our schema associations set up, we can implement the selection of categories in our product form. To do so, we need to translate the user input of catalog IDs from the front-end to our many-to-many association. Fortunately Ecto makes this a breeze now that our schema is set up. Open up your catalog context and make the following changes:

```diff
+ alias Hello.Catalog.Category

- def get_product!(id), do: Repo.get!(Product, id)
+ def get_product!(id) do
+   Product
+   |> Repo.get!(id)
+   |> Repo.preload(:categories)
+ end

  def create_product(attrs) do
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
  def category_opts(changeset) do
    existing_ids =
      changeset
      |> Ecto.Changeset.get_change(:categories, [])
      |> Enum.map(& &1.data.id)

    for cat <- Hello.Catalog.list_categories() do
      [key: cat.title, value: cat.id, selected: cat.id in existing_ids]
    end
  end
```

We added a new `category_opts/1` function which generates the select options for a multiple select tag we will add soon. We calculated the existing category IDs from our changeset, then used those values when we generate the select options for the input tag. We did this by enumerating over all of our categories and returning the appropriate `key`, `value`, and `selected` values. We marked an option as selected if the category ID was found in those category IDs in our changeset.

With our `category_opts` function in place, we can open up `lib/hello_web/controllers/product_html/product_form.html.heex` and add:

```diff
  ...
  <.input field={f[:views]} type="number" label="Views" />

+ <.input field={f[:category_ids]} type="select" multiple options={category_opts(@changeset)} />

  <.button>Save Product</.button>
```

We added a `category_select` above our save button. Now let's try it out. Next, let's show the product's categories in the product show template. Add the following code to the list in `lib/hello_web/controllers/product_html/show.html.heex`:

```diff
<.list>
  ...
+ <:item title="Categories">
+   <ul>
+     <li :for={cat <- @product.categories}>{cat.title}</li>
+   </ul>
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
