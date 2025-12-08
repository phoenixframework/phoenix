# 4. Cross-context Boundaries

Now that we have the beginnings of our product catalog features, let's begin to work on the other main features of our application – carting products from the catalog. In order to properly track products that have been added to a user's cart, we'll need a new place to persist this information, along with point-in-time product information like the price at time of carting. This is necessary so we can detect product price changes in the future. We know what we need to build, but now we need to decide where the cart functionality lives in our application.

If we take a step back and think about the isolation of our application, the exhibition of products in our catalog distinctly differs from the responsibilities of managing a user's cart. A product catalog shouldn't care about the rules of our shopping cart system, and vice-versa. There's a clear need here for a separate context to handle the new cart responsibilities. Let's call it `ShoppingCart`.

Let's create a `ShoppingCart` context to handle basic cart duties. Before we write code, let's imagine we have the following feature requirements:

  1. Add products to a user's cart from the product show page
  2. Store point-in-time product price information at time of carting
  3. Store and update quantities in cart
  4. Calculate and display sum of cart prices

From the description, it's clear we need a `Cart` resource for storing the user's cart, along with a `CartItem` to track products in the cart. With our plan set, let's get to work.

## Adding authentication

Most of the cart functionality is tied to a specific user. Therefore, in order to allow each user to manage their own cart (and only their own carts), we must be able to authenticate users. To do so, we will use Phoenix's built-in `mix phx.gen.auth` generator to scaffold a solution for us:

```console
mix phx.gen.auth Accounts User users
```

You will see output similar to the following: 

```console
An authentication system can be created in two different ways:
- Using Phoenix.LiveView (default)
- Using Phoenix.Controller only
Do you want to create a LiveView based authentication system? [Yn]
```

Type `n` followed by `Return` key,
you will see output similar to:

```console
...
* creating lib/hello/accounts/scope.ex
...
* injecting config/config.exs
...

Please re-fetch your dependencies with the following command:

    $ mix deps.get

Remember to update your repository by running migrations:

    $ mix ecto.migrate

Once you are ready, visit "/users/register"
to create your account and then access "/dev/mailbox" to
see the account confirmation email.
```

After following the instructions to re-fetch dependencies and migrating the database, we can start the server with `mix phx.server` and re-visit the home page [`http://localhost:4000/`](http://localhost:4000/). There, we should see new registration and login links at the top of the page. On the registration page, create a new user. In development, a confirmation email is sent to the dev mailbox, which is accessible at [`http://localhost:4000/dev/mailbox`](http://localhost:4000/dev/mailbox). After clicking the confirmation link, you should be successfully logged in.

One of the benefits of `mix phx.gen.auth` is that it also generates a scope file at `lib/hello/accounts/scope.ex`. In a nutshell, authentication tells us who a user is based on their email address, but it doesn't tell us the resources the user owns or has access to. In order to do so, we need authorization. Scopes help us tie generated resources, such as the Cart we will create, to users. Let's open up the file:

```elixir
defmodule Hello.Accounts.Scope do
  ...
  alias Hello.Accounts.User

  defstruct user: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil
end
```

We can see that it is simply a struct with a `user` field. The authentication system ensures that the `current_scope` assign is accordingly set with the current user. Let's see it in practice.

## Generating scoped resources

Let's generate our new context:

```console
$ mix phx.gen.context ShoppingCart Cart carts

* creating lib/hello/shopping_cart/cart.ex
* creating priv/repo/migrations/20250205203128_create_carts.exs
* creating lib/hello/shopping_cart.ex
* injecting lib/hello/shopping_cart.ex
* creating test/hello/shopping_cart_test.exs
* injecting test/hello/shopping_cart_test.exs
* creating test/support/fixtures/shopping_cart_fixtures.ex
* injecting test/support/fixtures/shopping_cart_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

We generated our new context `ShoppingCart`, with a new `ShoppingCart.Cart` schema. Open up the generated schema and migration files and you will see it has automatically included a `user_id` field, thanks to the scope. Furthermore, when we explore the code later on, we will learn all queries to the carts table have been properly scoped.

With our cart in place, let's generate our cart items. This time we will pass the `--no-scope` flag, because we will associate `cart_items` to `carts` and the `carts` are already scoped to the user:

```console
$ mix phx.gen.context ShoppingCart CartItem cart_items \
cart_id:references:carts product_id:references:products \
price_when_carted:decimal quantity:integer --no-scope

You are generating into an existing context.
...
Would you like to proceed? [Yn] y
* creating lib/hello/shopping_cart/cart_item.ex
* creating priv/repo/migrations/20250205213410_create_cart_items.exs
* injecting lib/hello/shopping_cart.ex
* injecting test/hello/shopping_cart_test.exs
* injecting test/support/fixtures/shopping_cart_fixtures.ex

Remember to update your repository by running migrations:

    $ mix ecto.migrate
```

We generated a new resource inside our `ShoppingCart` named `CartItem`. This schema and table will hold references to a cart and product, along with the price at the time we added the item to our cart, and the quantity the user wishes to purchase. Let's touch up the generated migration file in `priv/repo/migrations/*_create_cart_items.ex`:

```diff
    create table(:cart_items) do
-     add :price_when_carted, :decimal
+     add :price_when_carted, :decimal, precision: 15, scale: 6, null: false
      add :quantity, :integer
-     add :cart_id, references(:carts, on_delete: :nothing)
+     add :cart_id, references(:carts, on_delete: :delete_all)
-     add :product_id, references(:products, on_delete: :nothing)
+     add :product_id, references(:products, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

-   create index(:cart_items, [:cart_id])
    create index(:cart_items, [:product_id])
+   create unique_index(:cart_items, [:cart_id, :product_id])
```

We used the `:delete_all` strategy again to enforce data integrity. This way, when a cart or product is deleted from the application, we don't have to rely on application code in our `ShoppingCart` or `Catalog` contexts to worry about cleaning up the records. This keeps our application code decoupled and the data integrity enforcement where it belongs – in the database. We also added a unique constraint to ensure a duplicate product is not allowed to be added to a cart. As with the `product_categories` table, using a multi-column index lets us remove the separate index for the leftmost field (`cart_id`). With our database tables in place, we can now migrate up:

```console
$ mix ecto.migrate

16:59:51.941 [info] == Running 20250205203342 Hello.Repo.Migrations.CreateCarts.change/0 forward

16:59:51.945 [info] create table carts

16:59:51.952 [info] == Migrated 20250205203342 in 0.0s

16:59:51.988 [info] == Running 20250205213410 Hello.Repo.Migrations.CreateCartItems.change/0 forward

16:59:51.988 [info] create table cart_items

16:59:52.000 [info] create index cart_items_product_id_index

16:59:52.001 [info] create index cart_items_cart_id_product_id_index

16:59:52.002 [info] == Migrated 20250205213410 in 0.0s
```

Our database is ready to go with new `carts` and `cart_items` tables, but now we need to map that back into application code. You may be wondering how we can mix database foreign keys across different tables and how that relates to the context pattern of isolated, grouped functionality. Let's jump in and discuss the approaches and their tradeoffs.

## Cross-context data

So far, we've done a great job isolating the two main contexts of our application from each other, but now we have a necessary dependency to handle.

Our `Catalog.Product` resource serves to keep the responsibilities of representing a product inside the catalog, but ultimately for an item to exist in the cart, a product from the catalog must be present. Given this, our `ShoppingCart` context will have a data dependency on the `Catalog` context. With that in mind, we have two options. One is to expose APIs on the `Catalog` context that allows us to efficiently fetch product data for use in the `ShoppingCart` system, which we would manually stitch together. Or we can use database joins to fetch the dependent data. Both are valid options given your tradeoffs and application size, but joining data from the database when you have a hard data dependency is just fine for a large class of applications and is the approach we will take here.

Now that we know where our data dependencies exist, let's add our schema associations so we can tie shopping cart items to products. First, let's make a quick change to our cart schema in `lib/hello/shopping_cart/cart.ex` to associate a cart to its items:

```diff
  schema "carts" do
-   field :user_id, :id
+   belongs_to :user, Hello.Accounts.User
+   has_many :items, Hello.ShoppingCart.CartItem

    timestamps(type: :utc_datetime)
  end
```

Now that our cart is associated to the items we place in it, let's set up the cart item associations inside `lib/hello/shopping_cart/cart_item.ex`:

```diff
  schema "cart_items" do
    field :price_when_carted, :decimal
    field :quantity, :integer
-   field :cart_id, :id
-   field :product_id, :id

+   belongs_to :cart, Hello.ShoppingCart.Cart
+   belongs_to :product, Hello.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(cart_item, attrs) do
    cart_item
-   |> cast(attrs, [:price_when_carted, :quantity])
+   |> cast(attrs, [:quantity])
-   |> validate_required([:price_when_carted, :quantity])
+   |> validate_required([:quantity])
+   |> validate_number(:quantity, greater_than_or_equal_to: 0, less_than: 100)
  end
```

First, we replaced the `cart_id` field with a standard `belongs_to` pointing at our `ShoppingCart.Cart` schema. Next, we replaced our `product_id` field by adding our first cross-context data dependency with a `belongs_to` for the `Catalog.Product` schema. Here, we intentionally coupled the data boundaries because it provides exactly what we need: an isolated context API with the bare minimum knowledge necessary to reference a product in our system. Second, we remove `price_when_carted` from the list of permitted attributes to ensure any price provided by user input is discarded. Finally, we added a new validation to our changeset. With `validate_number/3`, we ensure any quantity provided by user input is between 0 and 100.

With our schemas in place, we can start integrating the new data structures and `ShoppingCart` context APIs into our web-facing features.

## Adding Cart functions

As we mentioned before, the context generators are only a starting point for our application. We can and should write well-named, purpose built functions to accomplish the goals of our context. We have a few new features to implement. First, we need to ensure every user of our application is granted a cart if one does not yet exist. From there, we can then allow users to add items to their cart, update item quantities, and calculate cart totals. Let's get started!

Because we used `mix phx.gen.auth`, we already have a real authentication system in place. We can use the `current_scope` assign to access the currently authenticated user. Let's add a new plug that assigns a cart if there is an authenticated user:

```diff
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelloWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
+   plug :fetch_current_cart
  end

+ alias Hello.ShoppingCart
+
+ defp fetch_current_cart(%{assigns: %{current_scope: scope}} = conn, _opts) when not is_nil(scope) do
+   if cart = ShoppingCart.get_cart(scope) do
+     assign(conn, :cart, cart)
+   else
+     {:ok, new_cart} = ShoppingCart.create_cart(scope, %{})
+     assign(conn, :cart, new_cart)
+   end
+ end
+
+ defp fetch_current_cart(conn, _opts), do: conn
```

We added a new `:fetch_current_cart` plug which either finds a cart for the user UUID or creates a cart for the current user and assigns the result in the connection assigns. We'll need to implement our `ShoppingCart.get_cart/1`, but let's add our routes first.

We'll need to implement a cart controller for handling cart operations like viewing a cart, updating quantities, and initiating the checkout process, as well as a cart items controller for adding and removing individual items to and from the cart. The authentication system already generated different router scopes that have different authentication requirements:

```elixir
...
  ## Authentication routes

  scope "/", HelloWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/user/register", UserRegistrationController, :new
    post "/user/register", UserRegistrationController, :create
  end

  scope "/", HelloWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/user/settings", UserSettingsController, :edit
    put "/user/settings", UserSettingsController, :update
    get "/user/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end
...
```

As you can see, the registration route has a `:redirect_if_user_is_authenticated` plug, which means it will redirect to the home page if the user is already authenticated. The user settings routes use a `:require_authenticated_user` plug, which means they will redirect to the log in page if the user is not authenticated. These plugs are defined in the `lib/hello_web/user_auth.ex` module.

For our cart routes, we want to only allow access to authenticated users. Add the following routes to your router in `lib/hello_web/router.ex`:

```diff
   scope "/", HelloWeb do
     pipe_through :browser

     get "/", PageController, :index
     resources "/products", ProductController
   end

+  scope "/", HelloWeb do
+    pipe_through [:browser, :require_authenticated_user]
+
+    resources "/cart_items", CartItemController, only: [:create, :delete]
+
+    get "/cart", CartController, :show
+    put "/cart", CartController, :update
+  end
```

We added a `resources` declaration for a `CartItemController`, which will wire up the routes for a create and delete action for adding and removing individual cart items. Next, we added two new routes pointing at a `CartController`. The first route, a GET request, will map to our show action, to show the cart contents. The second route, a PUT request, will handle the submission of a form for updating our cart quantities.

With our routes in place, let's add the ability to add an item to our cart from the product show page. Create a new file at `lib/hello_web/controllers/cart_item_controller.ex` and key this in:

```elixir
defmodule HelloWeb.CartItemController do
  use HelloWeb, :controller

  alias Hello.ShoppingCart

  def create(conn, %{"product_id" => product_id}) do
    case ShoppingCart.add_item_to_cart(conn.assigns.current_scope, conn.assigns.cart, product_id) do
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
    {:ok, _cart} = ShoppingCart.remove_item_from_cart(conn.assigns.current_scope, conn.assigns.cart, product_id)
    redirect(conn, to: ~p"/cart")
  end
end
```

We defined a new `CartItemController` with the create and delete actions that we declared in our router. For `create`, we call a `ShoppingCart.add_item_to_cart/3` function which we'll implement in a moment. If successful, we show a flash successful message and redirect to the cart show page; else, we show a flash error message and redirect to the cart show page. For `delete`, we'll call a `remove_item_from_cart` function which we'll implement on our `ShoppingCart` context  and then redirect back to the cart show page. We haven't implemented these two shopping cart functions yet, but notice how their names scream their intent: `add_item_to_cart` and `remove_item_from_cart` make it obvious what we are accomplishing here. It also allows us to spec out our web layer and context APIs without thinking about all the implementation details at once.

Let's implement the new interface for the `ShoppingCart` context API in `lib/hello/shopping_cart.ex`:

```diff
+  alias Hello.Catalog
-  alias Hello.ShoppingCart.Cart
+  alias Hello.ShoppingCart.{Cart, CartItem}
   alias Hello.Accounts.Scope

+  def get_cart(%Scope{} = scope) do
+    Repo.one(
+      from(c in Cart,
+        where: c.user_id == ^scope.user.id,
+        left_join: i in assoc(c, :items),
+        left_join: p in assoc(i, :product),
+        order_by: [asc: i.inserted_at],
+        preload: [items: {i, product: p}]
+      )
+    )
+  end

   def create_cart(%Scope{} = scope, attrs) do
     with {:ok, cart = %Cart{}} <-
            %Cart{}
            |> Cart.changeset(attrs, scope)
            |> Repo.insert() do
       broadcast(scope, {:created, cart})
-      {:ok, cart}
+      {:ok, get_cart(scope)}
     end
   end
+
+  def add_item_to_cart(%Scope{} = scope, %Cart{} = cart, product_id) do
+    true = cart.user_id == scope.user.id
+    product = Catalog.get_product!(product_id)
+
+    %CartItem{quantity: 1, price_when_carted: product.price}
+    |> CartItem.changeset(%{})
+    |> Ecto.Changeset.put_assoc(:cart, cart)
+    |> Ecto.Changeset.put_assoc(:product, product)
+    |> Repo.insert(
+      on_conflict: [inc: [quantity: 1]],
+      conflict_target: [:cart_id, :product_id]
+    )
+  end
+
+  def remove_item_from_cart(%Scope{} = scope, %Cart{} = cart, product_id) do
+    true = cart.user_id == scope.user.id
+
+    {1, _} =
+      Repo.delete_all(
+        from(i in CartItem,
+          where: i.cart_id == ^cart.id,
+          where: i.product_id == ^product_id
+        )
+      )
+
+    {:ok, get_cart(scope)}
+  end
```

We started by implementing `get_cart/1` which fetches our cart and joins the cart items, and their products so that we have the full cart populated with all preloaded data. Next, we modified our `create_cart` function to use `get_cart` to reload the cart contents.

Next, we wrote our new `add_item_to_cart/3` function which accepts a scope, a cart struct and a product id. We proceed to fetch the product with `Catalog.get_product!/1`, showing how contexts can naturally invoke other contexts if required. You could also have chosen to receive the product as argument and you would achieve similar results. Then we used an upsert operation against our repo to either insert a new cart item into the database, or increase the quantity by one if it already exists in the cart. This is accomplished via the `on_conflict` and `conflict_target` options, which tells our repo how to handle an insert conflict.

Finally, we implemented `remove_item_from_cart/3` where we simply issue a `Repo.delete_all` call with a query to delete the cart item in our cart that matches the product ID. Finally, we reload the cart contents by calling `get_cart/1`.

With our new cart functions in place, we can now expose the "Add to cart" button on the product catalog show page. Open up your template in `lib/hello_web/controllers/product_html/show.html.heex` and make the following changes:

```diff
...
     <.button variant="primary" navigate={~p"/products/#{@product}/edit?return_to=show"}>
       <.icon name="hero-pencil-square" /> Edit product
     </.button>
+    <.button href={~p"/cart_items?product_id=#{@product.id}"} method="post">
+      Add to cart
+    </.button>
...
```

The `link` function component from `Phoenix.Component` accepts a `:method` attribute to issue an HTTP verb when clicked, instead of the default GET request. With this link in place, the "Add to cart" link will issue a POST request, which will be matched by the route we defined in router which dispatches to the `CartItemController.create/2` function.

Let's try it out. Start your server with `mix phx.server` and visit a product page. If we try clicking the add to cart link, we'll be greeted by an error page. If you are authenticated the following logs should be visible in the console:

```text
[info] POST /cart_items
[debug] Processing with HelloWeb.CartItemController.create/2
  Parameters: %{"_method" => "post", "product_id" => "1", ...}
  Pipelines: [:browser, :require_authenticated_user]
[debug] QUERY OK source="user_tokens" db=2.4ms idle=1340.8ms
...
[debug] QUERY OK source="cart_items" db=2.5ms
INSERT INTO "cart_items" ...
[info] Sent 302 in 24ms
[info] GET /cart
[debug] Processing with HelloWeb.CartController.show/2
  Parameters: %{}
  Pipelines: [:browser, :require_authenticated_user]
[debug] QUERY OK source="user_tokens" db=1.6ms idle=430.2ms
...
[debug] QUERY OK source="carts" db=1.9ms idle=1798.5ms
...
[info] Sent 500 in 18ms
[error] ** (UndefinedFunctionError) function HelloWeb.CartController.init/1 is undefined (module HelloWeb.CartController is not available)
    ...
```

It's working! Kind of. If we follow the logs, we see our POST to the `/cart_items` path. Next, we can see our `ShoppingCart.add_item_to_cart` function successfully inserted a row into the `cart_items` table, and then we issued a redirect to `/cart`. Before our error, we also see a query to the `carts` table, which means we're fetching the current user's cart. So far so good. We know our `CartItem` controller and new `ShoppingCart` context functions are doing their jobs, but we've hit our next unimplemented feature when the router attempts to dispatch to a nonexistent cart controller. Let's create the cart controller, view, and template to display and manage user carts.

Create a new file at `lib/hello_web/controllers/cart_controller.ex` and key this in:

```elixir
defmodule HelloWeb.CartController do
  use HelloWeb, :controller

  alias Hello.ShoppingCart

  def show(conn, _params) do
    render(conn, :show, changeset: ShoppingCart.change_cart(conn.assigns.current_scope, conn.assigns.cart))
  end
end
```

We defined a new cart controller to handle the `get "/cart"` route. For showing a cart, we render a `"show.html"` template which we'll create in a moment. We know we need to allow the cart items to be changed by quantity updates, so right away we know we'll need a cart changeset. Fortunately, the context generator included a `ShoppingCart.change_cart/1` function, which we'll use. We pass it our cart struct which is already in the connection assigns thanks to the `fetch_current_cart` plug we defined in the router.

Next, we can implement the view and template. Create a new view file at `lib/hello_web/controllers/cart_html.ex` with the following content:

```elixir
defmodule HelloWeb.CartHTML do
  use HelloWeb, :html

  alias Hello.ShoppingCart

  embed_templates "cart_html/*"

  def currency_to_str(%Decimal{} = val), do: "$#{Decimal.round(val, 2)}"
end
```

We created a view to render our `show.html` template and aliased our `ShoppingCart` context so it will be in scope for our template. We'll need to display the cart prices like product item price, cart total, etc, so we defined a `currency_to_str/1` which takes our decimal struct, rounds it properly for display, and prepends a USD dollar sign.

Next we can create the template at `lib/hello_web/controllers/cart_html/show.html.heex`:

```heex
<Layouts.app flash={@flash}>
  <.header>
    My Cart
    <:subtitle :if={@cart.items == []}>Your cart is empty</:subtitle>
  </.header>

  <div :if={@cart.items !== []}>
    <.form :let={f} for={@changeset} action={~p"/cart"}>
      <.inputs_for :let={%{data: item} = item_form} field={f[:items]}>
        <.input field={item_form[:quantity]} type="number" label={item.product.title} />
        {currency_to_str(ShoppingCart.total_item_price(item))}
      </.inputs_for>
      <.button>Update cart</.button>
    </.form>
    <b>Total</b>: {currency_to_str(ShoppingCart.total_cart_price(@cart))}
  </div>

  <.button navigate={~p"/products"}>Back to products</.button>
</Layouts.app>
```

We started by showing the empty cart message if our preloaded `cart.items` is empty. If we have items, we use the `form` component provided by our `HelloWeb.CoreComponents` to take our cart changeset that we assigned in the `CartController.show/2` action and create a form which maps to our cart controller `update/2` action. Within the form, we use the [`inputs_for`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#inputs_for/1) component to render inputs for the nested cart items. This will allow us to map item inputs back together when the form is submitted. Next, we display a number input for the item quantity and label it with the product title. We finish the item form by converting the item price to string. We haven't written the `ShoppingCart.total_item_price/1` function yet, but again we employed the idea of clear, descriptive public interfaces for our contexts. After rendering inputs for all the cart items, we show an "update cart" submit button, along with the total price of the entire cart. This is accomplished with another new `ShoppingCart.total_cart_price/1` function which we'll implement in a moment. Finally, we added a `back` component to go back to our products page.

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
[info] POST /cart
...
[error] ** (UndefinedFunctionError) function HelloWeb.CartController.update/2 is undefined or private
```

Let's head back to our `CartController` at `lib/hello_web/controllers/cart_controller.ex` and implement the update action:

```elixir
  def update(conn, %{"cart" => cart_params}) do
    case ShoppingCart.update_cart(conn.assigns.current_scope, conn.assigns.cart, cart_params) do
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
  def update_cart(%Scope{} = scope, %Cart{} = cart, attrs) do
    true = cart.user_id == scope.user.id

    changeset =
      cart
      |> Cart.changeset(attrs, scope)
      |> Ecto.Changeset.cast_assoc(:items, with: &CartItem.changeset/2)
  
    Repo.transact(fn ->
      with {:ok, cart} <- Repo.update(changeset),
           {_count, _cart_items} = Repo.delete_all(from(i in CartItem, where: i.cart_id == ^cart.id and i.quantity == 0)) do
        {:ok, cart}
      end
    end)
    |> case do
      {:ok, cart} ->
        broadcast_cart(scope, {:updated, cart})
        {:ok, cart}

      {:error, reason} ->
        {:error, reason}
    end
  end
```

We started much like how our out-of-the-box code started – we take the cart struct and cast the user input to a cart changeset, except this time we use `Ecto.Changeset.cast_assoc/3` to cast the nested item data into `CartItem` changesets. Remember the [`<.inputs_for />`](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#inputs_for/1) call in our cart form template? That hidden ID data is what allows Ecto's `cast_assoc` to map item data back to existing item associations in the cart. 

Once the `changeset` is ready, we wrap everything in `Repo.transact/2` so the operations run safely as one. Inside the transaction, we update the cart using `Repo.update/1`. If the update succeeds, we follow up with a cleanup step using `Repo.delete_all/2` to remove any cart items with zero quantity. Running both steps in the same transaction prevents partial updates and keeps the cart data accurate. Finally, we broadcast the updated cart so that any connected LiveViews can instantly show the changes.

Let's head back to the browser and try it out. Add a few products to your cart, update the quantities, and watch the values changes along with the price calculations. Setting any quantity to 0 will also remove the item. You can also try logging out and registering a new user to see how the carts are scoped to the current user. Pretty neat!
