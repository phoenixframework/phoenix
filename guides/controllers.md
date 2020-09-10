# Controllers

> **Requirement**: This guide expects that you have gone through the introductory guides and got a Phoenix application up and running.

> **Requirement**: This guide expects that you have gone through [the Request life-cycle guide](request_lifecycle.html).

Phoenix controllers act as intermediary modules. Their functions - called actions - are invoked from the router in response to HTTP requests. The actions, in turn, gather all the necessary data and perform all the necessary steps before invoking the view layer to render a template or returning a JSON response.

Phoenix controllers also build on the Plug package, and are themselves plugs. Controllers provide the functions to do almost anything we need to in an action. If we do find ourselves looking for something that Phoenix controllers don't provide, we might find what we're looking for in Plug itself. Please see the [Plug Guide](plug.html) or [Plug Documentation](https://hexdocs.pm/plug/) for more information.

A newly generated Phoenix app will have a single controller, the `PageController`, which can be found at `lib/hello_web/controllers/page_controller.ex` and looks like this.

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
```

The first line below the module definition invokes the `__using__/1` macro of the `HelloWeb` module, which imports some useful modules.

The `PageController` gives us the `index` action to display the Phoenix welcome page associated with the default route Phoenix defines in the router.

## Actions

Controller actions are just functions. We can name them anything we like as long as they follow Elixir's naming rules. The only requirement we must fulfill is that the action name matches a route defined in the router.

For example, in `lib/hello_web/router.ex` we could change the action name in the default route that Phoenix gives us in a new app from index:

```elixir
get "/", PageController, :index
```

To test:

```elixir
get "/", PageController, :test
```

As long as we change the action name in the `PageController` to `test` as well, the welcome page will load as before.

```elixir
defmodule HelloWeb.PageController do
  ...

  def test(conn, _params) do
    render(conn, "index.html")
  end
end
```

While we can name our actions whatever we like, there are conventions for action names which we should follow whenever possible. We went over these in the [Routing Guide](routing.html), but we'll take another quick look here.

- index   - renders a list of all items of the given resource type
- show    - renders an individual item by id
- new     - renders a form for creating a new item
- create  - receives params for one new item and saves it in a datastore
- edit    - retrieves an individual item by id and displays it in a form for editing
- update  - receives params for one edited item and saves it to a datastore
- delete  - receives an id for an item to be deleted and deletes it from a datastore

Each of these actions takes two parameters, which will be provided by Phoenix behind the scenes.

The first parameter is always `conn`, a struct which holds information about the request such as the host, path elements, port, query string, and much more. `conn`, comes to Phoenix via Elixir's Plug middleware framework. More detailed info about `conn` can be found in [plug's documentation](https://hexdocs.pm/plug/Plug.Conn.html).

The second parameter is `params`. Not surprisingly, this is a map which holds any parameters passed along in the HTTP request. It is a good practice to pattern match against params in the function signature to provide data in a simple package we can pass on to rendering. We saw this in the [Request life-cycle guide](request_lifecycle.html) when we added a messenger parameter to our `show` route in `lib/hello_web/controllers/hello_controller.ex`.

```elixir
defmodule HelloWeb.HelloController do
  ...

  def show(conn, %{"messenger" => messenger}) do
    render(conn, "show.html", messenger: messenger)
  end
end
```

In some cases - often in `index` actions, for instance - we don't care about parameters because our behavior doesn't depend on them. In those cases, we don't use the incoming params, and simply prepend the variable name with an underscore, `_params`. This will keep the compiler from complaining about the unused variable while still keeping the correct arity.

## Rendering

Controllers have several ways of rendering content. The simplest is to render some plain text using the `text/2` function which Phoenix provides.

For example, let's rewrite the `show` action from `PageController` to return text instead. For that, we could do the following.

```elixir
def show(conn, %{"messenger" => messenger}) do
  text(conn, "From messenger #{messenger}")
end
```

Now `/hello/Frank` in your browser should display `From messenger Frank` as plain text without any HTML.

A step beyond this is rendering pure JSON with the `json/2` function. We need to pass it something that the [Jason library](https://github.com/michalmuskala/jason) can decode into JSON, such as a map. (Jason is one of Phoenix's dependencies.)

```elixir
def show(conn, %{"messenger" => messenger}) do
  json(conn, %{id: messenger})
end
```

If we again visit `/hello/Frank` in the browser, we should see a block of JSON with the key `id` mapped to the string `"Frank"`.

```json
{"id": "Frank"}
```

Phoenix controllers can also render HTML without a view. As you may have already guessed, the `html/2` function does just that. This time, we implement the `show` action like this.

```elixir
def show(conn, %{"messenger" => messenger}) do
  html(conn, """
   <html>
     <head>
        <title>Passing a Messenger</title>
     </head>
     <body>
       <p>From messenger #{Plug.HTML.html_escape(messenger)}</p>
     </body>
   </html>
  """)
end
```

Hitting `/hello/Frank` now renders the HTML string we defined in the `show` action. Note that what we wrote in the action is not an `eex` template. It's a multi-line string, so we interpolate the `messenger` variable like this `#{Plug.HTML.html_escape(messenger)}`, instead of this `<%= messenger %>`.

It is worth noting that the `text/2`, `json/2`, and `html/2` functions require neither a Phoenix view, nor a template to render.

The `json/2` function is obviously useful for writing APIs, and the other two may come in handy, but most of the times we use Phoenix views to build our responses. For this, Phoenix provides the `render/3` function.

Let's rollback our `show` action to what we originally wrote [in the Request life-cycle guide](request_lifecycle.html):

```elixir
defmodule HelloWeb.HelloController do
  use HelloWeb, :controller

  def show(conn, %{"messenger" => messenger}) do
    render(conn, "show.html", messenger: messenger)
  end
end
```

In order for the `render/3` function to work correctly, the controller and view must have the same root name, which must also have the same root name as the template directory where the `show.html.eex` template lives. In other words, the `HelloController` requires `HelloView`, and `HelloView` requires the existence of the `lib/hello_web/templates/hello` directory, which must contain the `show.html.eex` template.

`render/3` will also pass the value which the `show` action received for `messenger` from the params as an assign.

If we need to pass values into the template when using `render`, that's easy. We can pass a keyword like we've seen with `messenger: messenger`, or we can use `Plug.Conn.assign/3`, which conveniently returns `conn`.

```elixir
  def show(conn, %{"messenger" => messenger}) do
    conn
    |> Plug.Conn.assign(:messenger, messenger)
    |> render("show.html")
  end
```

Note: Using `Phoenix.Controller` imports `Plug.Conn`, so shortening the call to `assign/3` works just fine.

Passing more than one value in to our template is as simple as connecting `assign/3` functions together:

```elixir
  def show(conn, %{"messenger" => messenger}) do
    conn
    |> assign(:messenger, messenger)
    |> assign(:receiver, "Dweezil")
    |> render("show.html")
  end
```

Generally speaking, once all assigns are configured, we invoke the View layer. The View layer then renders "show.html" alongside the layout and a response is sent back to the browser.

[Views and templates](views.html) have their own guide, so we won't spend much time on them here. What we will look at is how to assign a different layout, or none at all, from inside a controller action.

### Assigning Layouts

Layouts are just a special subset of templates. They live in `lib/hello_web/templates/layout`. Phoenix created one for us when we generated our app. The default layout is called `app.html.eex`, and it is the layout into which all templates will be rendered by default.

Since layouts are really just templates, they need a view to render them. This is the `LayoutView` module defined in `lib/hello_web/views/layout_view.ex`. Since Phoenix generated this view for us, we won't have to create a new one as long as we put the layouts we want to render inside the `lib/hello_web/templates/layout` directory.

Before we create a new layout, though, let's do the simplest possible thing and render a template with no layout at all.

The `Phoenix.Controller` module provides the `put_layout/2` function for us to switch layouts. This takes `conn` as its first argument and a string for the basename of the layout we want to render. It also accepts `false` to disable the layout altogether.

Edit the `index` action of the `PageController` module `lib/hello_web/controllers/page_controller.ex` to look like this.

```elixir
def index(conn, _params) do
  conn
  |> put_layout(false)
  |> render("index.html")
end
```

After reloading [http://localhost:4000/](http://localhost:4000/), we should see a very different page, one with no title, logo image, or CSS styling at all.

Now let's actually create another layout and render the index template into it. As an example, let's say we had a different layout for the admin section of our application which didn't have the logo image. To do this, let's copy the existing `app.html.eex` to a new file `admin.html.eex` in the same directory `lib/hello_web/templates/layout`. Then let's remove the line in `admin.html.eex` that displays the logo.

```html
<span class="logo"></span> <!-- remove this line -->
```

Then, pass the basename of the new layout into `put_layout/2` in our `index` action in `lib/hello_web/controllers/page_controller.ex`.

```elixir
def index(conn, _params) do
  conn
  |> put_layout("admin.html")
  |> render("index.html")
end
```

When we load the page, we should be rendering the admin layout without a logo.

### Overriding Rendering Formats

Rendering HTML through a template is fine, but what if we need to change the rendering format on the fly? Let's say that sometimes we need HTML, sometimes we need plain text, and sometimes we need JSON. Then what?

Phoenix allows us to change formats on the fly with the `_format` query string parameter. To make this happen, Phoenix requires an appropriately named view and an appropriately named template in the correct directory.

As an example, let's take the `PageController` index action from a newly generated app. Out of the box, this has the right view, `PageView`, the right templates directory, `lib/hello_web/templates/page`, and the right template for rendering HTML, `index.html.eex`.

```elixir
def index(conn, _params) do
  render(conn, "index.html")
end
```

What it doesn't have is an alternative template for rendering text. Let's add one at `lib/hello_web/templates/page/index.text.eex`. Here is our example `index.text.eex` template.

```html
OMG, this is actually some text.
```

There are just a few more things we need to do to make this work. We need to tell our router that it should accept the `text` format. We do that by adding `text` to the list of accepted formats in the `:browser` pipeline. Let's open up `lib/hello_web/router.ex` and change the `plug :accepts` to include `text` as well as `html` like this.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html", "text"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
...
```

We also need to tell the controller to render a template with the same format as the one returned by `Phoenix.Controller.get_format/1`. We do that by substituting the name of the template "index.html" with the atom version `:index`.

```elixir
def index(conn, _params) do
  render(conn, :index)
end
```

If we go to [`http://localhost:4000/?_format=text`](http://localhost:4000/?_format=text), we will see "OMG, this is actually some text.".

### Sending responses directly

If none of the rendering options above quite fits our needs, we can compose our own using some of the functions that Plug gives us. Let's say we want to send a response with a status of "201" and no body whatsoever. We can easily do that with the `Plug.Conn.send_resp/3` function.

Edit the `index` action of the `PageController` module `lib/hello_web/controllers/page_controller.ex` to look like this:

```elixir
def index(conn, _params) do
  conn
  |> send_resp(201, "")
end
```

Reloading [http://localhost:4000](http://localhost:4000) should show us a completely blank page. The network tab of our browser's developer tools should show a response status of "201".

If we would like to be really specific about the content type, we can use `put_resp_content_type/2` in conjunction with `send_resp/3`.

```elixir
def index(conn, _params) do
  conn
  |> put_resp_content_type("text/plain")
  |> send_resp(201, "")
end
```

Using Plug functions in this way, we can craft just the response we need.

### Setting the Content Type

Analogous to the `_format` query string param, we can render any sort of format we want by modifying the HTTP Content-Type Header and providing the appropriate template.

If we wanted to render an xml version of our `index` action, we might implement the action like this in `lib/hello_web/page_controller.ex`.

```elixir
def index(conn, _params) do
  conn
  |> put_resp_content_type("text/xml")
  |> render("index.xml", content: some_xml_content)
end
```

We would then need to provide an `index.xml.eex` template which created valid xml, and we would be done.

For a list of valid content mime-types, please see the [mime.types](https://github.com/elixir-plug/mime/blob/master/priv/mime.types) documentation from the mime type library.

### Setting the HTTP Status

We can also set the HTTP status code of a response similarly to the way we set the content type. The `Plug.Conn` module, imported into all controllers, has a `put_status/2` function to do this.

`Plug.Conn.put_status/2` takes `conn` as the first parameter and as the second parameter either an integer or a "friendly name" used as an atom for the status code we want to set. The list of status code atom representations can be found in `Plug.Conn.Status.code/1` documentation.

Let's change the status in our `PageController` `index` action.

```elixir
def index(conn, _params) do
  conn
  |> put_status(202)
  |> render("index.html")
end
```

The status code we provide must be a valid number.

## Redirection

Often, we need to redirect to a new url in the middle of a request. A successful `create` action, for instance, will usually redirect to the `show` action for the resource we just created. Alternately, it could redirect to the `index` action to show all the things of that same type. There are plenty of other cases where redirection is useful as well.

Whatever the circumstance, Phoenix controllers provide the handy `redirect/2` function to make redirection easy. Phoenix differentiates between redirecting to a path within the application and redirecting to a url - either within our application or external to it.

In order to try out `redirect/2`, let's create a new route in `lib/hello_web/router.ex`.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router
  ...

  scope "/", HelloWeb do
    ...
    get "/", PageController, :index
    get "/redirect_test", PageController, :redirect_test
  end
end
```

Then we'll change the `index` action to do nothing but redirect to our new route.

```elixir
def index(conn, _params) do
  redirect(conn, to: "/redirect_test")
end
```

Finally, let's define in the same file the action we redirect to, which simply renders the index, but now under a new address:

```elixir
def redirect_test(conn, _params) do
  render(conn, "index.html")
end
```

When we reload our [Welcome Page](http://localhost:4000), we see that we've been redirected to `/redirect_test` which shows the original welcome page. It works!

If we care to, we can open up our developer tools, click on the network tab, and visit our root route again. We see two main requests for this page - a get to `/` with a status of `302`, and a get to `/redirect_test` with a status of `200`.

Notice that the redirect function takes `conn` as well as a string representing a relative path within our application. For security reasons, the `:to` helper can only redirect for paths within your application. If you want to redirect to a fully-qualified path or an external URL, you should use `:external` instead:

```elixir
def index(conn, _params) do
  redirect(conn, external: "https://elixir-lang.org/")
end
```

We can also make use of the path helpers we learned about in the [Routing Guide](routing.html).

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: Routes.page_path(conn, :redirect_test))
  end
end
```

Using route helpers is actually the preferred approach to link to any page within our application.

## Flash Messages

There are times when we need to communicate with users during the course of an action. Maybe there was an error updating a schema. Maybe we just want to welcome them back to the application. For this, we have flash messages.

The `Phoenix.Controller` module provides the `put_flash/3` and `get_flash/2` functions to help us set and retrieve flash messages as a key value pair. Let's set two flash messages in our `HelloWeb.PageController` to try this out.

To do this we modify the `index` action as follows:

```elixir
defmodule HelloWeb.PageController do
  ...
  def index(conn, _params) do
    conn
    |> put_flash(:info, "Welcome to Phoenix, from flash info!")
    |> put_flash(:error, "Let's pretend we have an error.")
    |> render("index.html")
  end
end
```

In order to see our flash messages, we need to be able to retrieve them and display them in a template/layout. One way to do the first part is with `get_flash/2` which takes `conn` and the key we care about. It then returns the value for that key.

Fortunately, our application layout, `lib/hello_web/templates/layout/app.html.eex`, already has markup for displaying flash messages.

```html
<p class="alert alert-info" role="alert"><%= get_flash(@conn, :info) %></p>
<p class="alert alert-danger" role="alert"><%= get_flash(@conn, :error) %></p>
```

When we reload the [Welcome Page](http://localhost:4000/), our messages should appear just above "Welcome to Phoenix!"

The flash functionality is handy when mixed with redirects. Perhaps you want to redirect to a page with some extra information. If we re-use the redirect action from the previous section, we can do:

```elixir
  def index(conn, _params) do
    conn
    |> put_flash(:info, "Welcome to Phoenix, from flash info!")
    |> put_flash(:error, "Let's pretend we have an error.")
    |> redirect(to: Routes.page_path(conn, :redirect_test))
  end
```

Now if you reload the Welcome page, you will be redirected and the flash messages will be shown once more.

Besides `put_flash/3` and `get_flash/2`, the `Phoenix.Controller` module has another useful function worth knowing about. `clear_flash/1` takes only `conn` and removes any flash messages which might be stored in the session.

Phoenix does not enforce which keys are stored in the flash. As long as we are internally consistent, all will be well. `:info` and `:error`, however, are common and are handled by default in our templates.

## Action Fallback

Action Fallback allows us to centralize error handling code in plugs which are called when a controller action fails to return a `%Plug.Conn{}` struct. These plugs receive both the `conn` which was originally passed to the controller action along with the return value of the action.

Let's say we have a `show` action which uses `with` to fetch a blog post and then authorize the current user to view that blog post. In this example we might expect `fetch_post/1` to return `{:error, :not_found}` if the post is not found and `authorize_user/3` might return `{:error, :unauthorized}` if the user is unauthorized. We could use the `ErrorView` Phoenix generates for every new application to handle these error paths accordingly:

```elixir
defmodule HelloWeb.MyController do
  use Phoenix.Controller

  def show(conn, %{"id" => id}, current_user) do
    with {:ok, post} <- fetch_post(id),
         :ok <- authorize_user(current_user, :view, post) do
      render(conn, "show.json", post: post)
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> put_view(HelloWeb.ErrorView)
        |> render(:"404")

      {:error, :unauthorized} ->
        conn
        |> put_status(403)
        |> put_view(HelloWeb.ErrorView)
        |> render(:"403")
    end
  end
end
```

Now imagine you may need to implement similar logic for every controller and action handled by your API. This would result in a lot of repetition.

Instead we can define a Module Plug which knows how to handle these error cases specifically. Since controllers are Module Plugs, let's define our Plug as a controller:

```elixir
defmodule HelloWeb.MyFallbackController do
  use Phoenix.Controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(HelloWeb.ErrorView)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(403)
    |> put_view(HelloWeb.ErrorView)
    |> render(:"403")
  end
end
```

Then we can reference our new controller as the `action_fallback` and simply remove the `else` block from our `with`:

```elixir
defmodule HelloWeb.MyController do
  use Phoenix.Controller

  action_fallback HelloWeb.MyFallbackController

  def show(conn, %{"id" => id}, current_user) do
    with {:ok, post} <- fetch_post(id),
         :ok <- authorize_user(current_user, :view, post) do
      render(conn, "show.json", post: post)
    end
  end
end
```

Whenever the `with` conditions do not match, `HelloWeb.MyFallbackController` will receive the original `conn` as well as the result of the action and respond appropriately.
