# Controllers

> **Requirement**: This guide expects that you have gone through the [introductory guides](installation.html) and got a Phoenix application [up and running](up_and_running.html).

> **Requirement**: This guide expects that you have gone through the [request life-cycle guide](request_lifecycle.html).

Phoenix controllers act as intermediary modules. Their functions — called actions — are invoked from the router in response to HTTP requests. The actions, in turn, gather all the necessary data and perform all the necessary steps before invoking the view layer to render a template or returning a JSON response.

Phoenix controllers also build on the Plug package, and are themselves plugs. Controllers provide the functions to do almost anything we need to in an action. If we do find ourselves looking for something that Phoenix controllers don't provide, we might find what we're looking for in Plug itself. Please see the [Plug guide](plug.html) or the [Plug documentation](`Plug`) for more information.

A newly generated Phoenix app will have a single controller named `PageController`, which can be found at `lib/hello_web/controllers/page_controller.ex` which looks like this:

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
```

The first line below the module definition invokes the `__using__/1` macro of the `HelloWeb` module, which imports some useful modules.

`PageController` gives us the `index` action to display the Phoenix [welcome page] associated with the default route Phoenix defines in the router.

## Actions

Controller actions are just functions. We can name them anything we like as long as they follow Elixir's naming rules. The only requirement we must fulfill is that the action name matches a route defined in the router.

For example, in `lib/hello_web/router.ex` we could change the action name in the default route that Phoenix gives us in a new app from `home`:

```elixir
get "/", PageController, :home
```

to `index`:

```elixir
get "/", PageController, :index
```

as long as we change the action name in `PageController` to `index` as well, the [welcome page] will load as before.

```elixir
defmodule HelloWeb.PageController do
  ...

  def index(conn, _params) do
    render(conn, :index)
  end
end
```

While we can name our actions whatever we like, there are conventions for action names which we should follow whenever possible. We went over these in the [routing guide](routing.html), but we'll take another quick look here.

- index   - renders a list of all items of the given resource type
- show    - renders an individual item by ID
- new     - renders a form for creating a new item
- create  - receives parameters for one new item and saves it in a data store
- edit    - retrieves an individual item by ID and displays it in a form for editing
- update  - receives parameters for one edited item and saves the item to a data store
- delete  - receives an ID for an item to be deleted and deletes it from a data store

Each of these actions takes two parameters, which will be provided by Phoenix behind the scenes.

The first parameter is always `conn`, a struct which holds information about the request such as the host, path elements, port, query string, and much more. `conn` comes to Phoenix via Elixir's Plug middleware framework. More detailed information about `conn` can be found in the [Plug.Conn documentation](`Plug.Conn`).

The second parameter is `params`. Not surprisingly, this is a map which holds any parameters passed along in the HTTP request. It is a good practice to pattern match against parameters in the function signature to provide data in a simple package we can pass on to rendering. We saw this in the [request life-cycle guide](request_lifecycle.html) when we added a messenger parameter to our `show` route in `lib/hello_web/controllers/hello_controller.ex`.

```elixir
defmodule HelloWeb.HelloController do
  ...

  def show(conn, %{"messenger" => messenger}) do
    render(conn, :show, messenger: messenger)
  end
end
```

In some cases — often in `index` actions, for instance — we don't care about parameters because our behavior doesn't depend on them. In those cases, we don't use the incoming parameters, and simply prefix the variable name with an underscore, calling it `_params`. This will keep the compiler from complaining about the unused variable while still keeping the correct arity.

## Rendering

Controllers can render content in several ways. The simplest is to render some plain text using the [`text/2`] function which Phoenix provides.

For example, let's rewrite the `show` action from `HelloController` to return text instead. For that, we could do the following.

```elixir
def show(conn, %{"messenger" => messenger}) do
  text(conn, "From messenger #{messenger}")
end
```

Now [`/hello/Frank`] in your browser should display `From messenger Frank` as plain text without any HTML.

A step beyond this is rendering pure JSON with the [`json/2`] function. We need to pass it something that the [Jason library](`Jason`) can decode into JSON, such as a map. (Jason is one of Phoenix's dependencies.)

```elixir
def show(conn, %{"messenger" => messenger}) do
  json(conn, %{id: messenger})
end
```

If we again visit [`/hello/Frank`] in the browser, we should see a block of JSON with the key `id` mapped to the string `"Frank"`.

```json
{"id": "Frank"}
```

The [`json/2`] function is useful for writing APIs and there is also the [`html/2`] function for rendering HTML, but most of the times we use Phoenix views to build our responses. For this, Phoenix includes the [`render/3`] function. It is specially important for HTML responses, as Phoenix Views provide performance and security benefits.

Let's rollback our `show` action to what we originally wrote in the [request life-cycle guide](request_lifecycle.html):

```elixir
defmodule HelloWeb.HelloController do
  use HelloWeb, :controller

  def show(conn, %{"messenger" => messenger}) do
    render(conn, :show, messenger: messenger)
  end
end
```

In order for the [`render/3`] function to work correctly, the controller and view must share the same root name (in this case `Hello`), and the `HelloHTML` module must include an `embed_templates` definition specifying where its templates live. By default the controller, view module, and templates are collocated together in the same controller directory. In other words, `HelloController` requires `HelloHTML`, and `HelloHTML` requires the existence of the `lib/hello_web/controllers/hello_html/` directory, which must contain the `show.html.heex` template.

[`render/3`] will also pass the value which the `show` action received for `messenger` from the parameters as an assign.

If we need to pass values into the template when using `render`, that's easy. We can pass a keyword like we've seen with `messenger: messenger`, or we can use `Plug.Conn.assign/3`, which conveniently returns `conn`.

```elixir
  def show(conn, %{"messenger" => messenger}) do
    conn
    |> Plug.Conn.assign(:messenger, messenger)
    |> render(:show)
  end
```

Note: Using `Phoenix.Controller` imports `Plug.Conn`, so shortening the call to [`assign/3`] works just fine.

Passing more than one value to our template is as simple as connecting [`assign/3`] functions together:

```elixir
  def show(conn, %{"messenger" => messenger}) do
    conn
    |> assign(:messenger, messenger)
    |> assign(:receiver, "Dweezil")
    |> render(:show)
  end
```

Or you can pass the assigns directly to `render` instead:

```elixir
  def show(conn, %{"messenger" => messenger}) do
    render(conn, :show, messenger: messenger, receiver: "Dweezil")
  end
```

Generally speaking, once all assigns are configured, we invoke the view layer. The view layer (`HelloWeb.HelloHTML`) then renders `show.html` alongside the layout and a response is sent back to the browser.

[Components and HEEx templates](components.html) have their own guide, so we won't spend much time on them here. What we will look at is how to render different formats from inside a controller action.

## New rendering formats

Rendering HTML through a template is fine, but what if we need to change the rendering format on the fly? Let's say that sometimes we need HTML, sometimes we need plain text, and sometimes we need JSON. Then what?

The view's job is not only to render HTML templates. Views are about data presentation. Given a bag of data, the view's purpose is to present that in a meaningful way given some format, be it HTML, JSON, CSV, or others. Many web apps today return JSON to remote clients, and Phoenix views are *great* for JSON rendering.

As an example, let's take `PageController`'s `index` action from a newly generated app. Out of the box, this has the right view `PageHTML`, the embedded templates from (`lib/hello_web/controllers/page_html`), and the right template for rendering HTML (`index.html.heex`.)

```elixir
def index(conn, _params) do
  render(conn, :index)
end
```

What it doesn't have is a view for rendering JSON. Phoenix Controller hands off to a view module to render templates, and it does so per format. We already have a view for the HTML format, but we need to instruct Phoenix how to render the JSON format as well. By default, you can see which formats your controllers support in `lib/hello_web.ex`:

```elixir
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: HelloWeb.Layouts]
      ...
    end
  end
```

So out of the box Phoenix will look for a `HTML` and `JSON` view modules based on the request format and the controller name. We can also explicitly tell Phoenix in our controller which view(s) to use for each format. For example, what Phoenix does by default can be explicitly set with the following in your controller:

```elixir
plug :put_view, html: HelloWeb.PageHTML, json: HelloWeb.PageJSON
```

Let's add a `PageJSON` view module at `lib/hello_web/controllers/page_json.ex`:

```elixir
defmodule HelloWeb.PageJSON do
  def index(_assigns) do
    %{message: "this is some JSON"}
  end
end
```

Since the Phoenix View layer is simply a function that the controller renders, passing connection assigns, we can define a regular `index/1` function and return a map to be serialized as JSON.

There are just a few more things we need to do to make this work. Because we want to render both HTML and JSON from the same controller, we need to tell our router that it should accept the `json` format. We do that by adding `json` to the list of accepted formats in the `:browser` pipeline. Let's open up `lib/hello_web/router.ex` and change `plug :accepts` to include `json` as well as `html` like this.

```elixir
defmodule HelloWeb.Router do
  use HelloWeb, :router

  pipeline :browser do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {HelloWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end
...
```

Phoenix allows us to change formats on the fly with the `_format` query string parameter. If we go to [`http://localhost:4000/?_format=json`](http://localhost:4000/?_format=json), we will see `%{"message": "this is some JSON"}`.

In practice, however, applications that need to render both formats typically use two distinct pipelines for each, such as the `pipeline :api` already defined in your router file. To learn more, see [our JSON and APIs guide](json_and_apis.md).

### Sending responses directly

If none of the rendering options above quite fits our needs, we can compose our own using some of the functions that `Plug` gives us. Let's say we want to send a response with a status of "201" and no body whatsoever. We can do that with the `Plug.Conn.send_resp/3` function.

Edit the `index` action of `PageController` in `lib/hello_web/controllers/page_controller.ex` to look like this:

```elixir
def index(conn, _params) do
  send_resp(conn, 201, "")
end
```

Reloading [http://localhost:4000](http://localhost:4000) should show us a completely blank page. The network tab of our browser's developer tools should show a response status of "201" (Created). Some browsers (Safari) will download the response, as the content type is not set.

To be specific about the content type, we can use [`put_resp_content_type/2`] in conjunction with [`send_resp/3`].

```elixir
def index(conn, _params) do
  conn
  |> put_resp_content_type("text/plain")
  |> send_resp(201, "")
end
```

Using `Plug` functions in this way, we can craft just the response we need.

### Setting the content type

Analogous to the `_format` query string param, we can render any sort of format we want by modifying the HTTP Content-Type Header and providing the appropriate template.

If we wanted to render an XML version of our `index` action, we might implement the action like this in `lib/hello_web/page_controller.ex`.

```elixir
def index(conn, _params) do
  conn
  |> put_resp_content_type("text/xml")
  |> render(:index, content: some_xml_content)
end
```

We would then need to provide an `index.xml.eex` template which created valid XML, and we would be done.

For a list of valid content mime-types, please see the `MIME` library.

### Setting the HTTP Status

We can also set the HTTP status code of a response similarly to the way we set the content type. The `Plug.Conn` module, imported into all controllers, has a `put_status/2` function to do this.

`Plug.Conn.put_status/2` takes `conn` as the first parameter and as the second parameter either an integer or a "friendly name" used as an atom for the status code we want to set. The list of status code atom representations can be found in `Plug.Conn.Status.code/1` documentation.

Let's change the status in our `PageController` `index` action.

```elixir
def index(conn, _params) do
  conn
  |> put_status(202)
  |> render(:index)
end
```

The status code we provide must be a valid number.

## Redirection

Often, we need to redirect to a new URL in the middle of a request. A successful `create` action, for instance, will usually redirect to the `show` action for the resource we just created. Alternately, it could redirect to the `index` action to show all the things of that same type. There are plenty of other cases where redirection is useful as well.

Whatever the circumstance, Phoenix controllers provide the handy [`redirect/2`] function to make redirection easy. Phoenix differentiates between redirecting to a path within the application and redirecting to a URL — either within our application or external to it.

In order to try out [`redirect/2`], let's create a new route in `lib/hello_web/router.ex`.

```elixir
defmodule HelloWeb.Router do
  ...

  scope "/", HelloWeb do
    ...
    get "/", PageController, :index
    get "/redirect_test", PageController, :redirect_test
    ...
  end
end
```

Then we'll change `PageController`'s `index` action of our controller to do nothing but to redirect to our new route.

```elixir
defmodule HelloWeb.PageController do
  use HelloWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: ~p"/redirect_test")
  end
end

```

We made use of `Phoenix.VerifiedRoutes.sigil_p/2` to build our redirect path, which is the preferred approach to reference any path within our application. We learned about verified routes in the [routing guide](routing.html).

Finally, let's define in the same file the action we redirect to, which simply renders the index, but now under a new address:

```elixir
def redirect_test(conn, _params) do
  render(conn, :index)
end
```

When we reload our [welcome page], we see that we've been redirected to `/redirect_test` which shows the original welcome page. It works!

If we care to, we can open up our developer tools, click on the network tab, and visit our root route again. We see two main requests for this page - a get to `/` with a status of `302`, and a get to `/redirect_test` with a status of `200`.

Notice that the redirect function takes `conn` as well as a string representing a relative path within our application. For security reasons, the `:to` option can only redirect to paths within your application. If you want to redirect to a fully-qualified path or an external URL, you should use `:external` instead:

```elixir
def index(conn, _params) do
  redirect(conn, external: "https://elixir-lang.org/")
end
```

## Flash messages

Sometimes we need to communicate with users during the course of an action. Maybe there was an error updating a schema, or maybe we just want to welcome them back to the application. For this, we have flash messages.

The `Phoenix.Controller` module provides the [`put_flash/3`] to set flash messages as a key-value pair and placing them into a `@flash` assign in the connection. Let's set two flash messages in our `HelloWeb.PageController` to try this out.

To do this we modify the `index` action as follows:

```elixir
defmodule HelloWeb.PageController do
  ...
  def index(conn, _params) do
    conn
    |> put_flash(:info, "Welcome to Phoenix, from flash info!")
    |> put_flash(:error, "Let's pretend we have an error.")
    |> render(:index)
  end
end
```

In order to see our flash messages, we need to be able to retrieve them and display them in a template layout. We can do that using [`Phoenix.Flash.get/2`] which takes the flash data and the key we care about. It then returns the value for that key.

For our convenience, the application layout, `lib/hello_web/components/layouts/app.html.heex`, already has markup for displaying flash messages.

```heex
<.flash kind={:info} title="Success!" flash={@flash} />
<.flash kind={:error} title="Error!" flash={@flash} />
<.flash
  id="disconnected"
  kind={:error}
  title="We can't find the internet"
  close={false}
  autoshow={false}
  phx-disconnected={show("#disconnected")}
  phx-connected={hide("#disconnected")}
>
  Attempting to reconnect <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 inline animate-spin" />
</.flash>
```

When we reload the [welcome page], our messages should appear just above "Welcome to Phoenix!"

The flash functionality is handy when mixed with redirects. Perhaps you want to redirect to a page with some extra information. If we reuse the redirect action from the previous section, we can do:

```elixir
  def index(conn, _params) do
    conn
    |> put_flash(:info, "Welcome to Phoenix, from flash info!")
    |> put_flash(:error, "Let's pretend we have an error.")
    |> redirect(to: ~p"/redirect_test"))
  end
```

Now if you reload the [welcome page], you will be redirected and the flash messages will be shown once more.

Besides [`put_flash/3`], the `Phoenix.Controller` module has another useful function worth knowing about. [`clear_flash/1`] takes only `conn` and removes any flash messages which might be stored in the session.

Phoenix does not enforce which keys are stored in the flash. As long as we are internally consistent, all will be well. `:info` and `:error`, however, are common and are handled by default in our templates.

## Error pages

Phoenix has two views called `ErrorHTML` and `ErrorJSON` which live in `lib/hello_web/controllers/`. The purpose of these views is to handle errors in a general way for incoming HTML or JSON requests. Similar to the views we built in this guide, error views can return both HTML and JSON responses. See the [Custom Error Pages How-To](custom_error_pages.html) for more information.

[`render/4`]: `Phoenix.Template.render/4`
[`/hello/Frank`]:  http://localhost:4000/hello/Frank
[`assign/3`]: `Plug.Conn.assign/3`
[`clear_flash/1`]: `Phoenix.Controller.clear_flash/1`
[`Phoenix.Flash.get/2`]: `Phoenix.Flash.get/2`
[`html/2`]: `Phoenix.Controller.html/2`
[`json/2`]: `Phoenix.Controller.json/2`
[`put_flash/3`]: `Phoenix.Controller.put_flash/3`
[`put_resp_content_type/2`]: `Plug.Conn.put_resp_content_type/2`
[`put_root_layout/2`]: `Phoenix.Controller.put_root_layout/2`
[`redirect/2`]: `Phoenix.Controller.redirect/2`
[`render/3`]: `Phoenix.Controller.render/3`
[`send_resp/3`]: `Plug.Conn.send_resp/3`
[`text/2`]: `Phoenix.Controller.text/2`
[welcome page]: http://localhost:4000/
