##Controller Guide

Phoenix controllers act as a sort of intermediary modules. Their functions - called actions - are invoked from the router in response to HTTP requests. The actions, in turn, gather all the necessary data and perform all the necessary steps before - in a typical case - invoking the view layer to render a template.

A newly generated Phoenix app will have a single controller, the PageController, which looks like this.

```elixir
defmodule HelloPhoenix.PageController do
  use Phoenix.Controller

  def index(conn, _params) do
    render conn, "index"
  end

  def not_found(conn, _params) do
    render conn, "not_found"
  end

  def error(conn, _params) do
    render conn, "error"
  end
end
```

This gives us the index action to display the Phoenix welcome page associated with the default route Phoenix gives us in the router. It also gives us generic actions to handle 404 Page not Found and 500 Internal Error responses.

###Actions
Controller actions are just functions. We can name them anything we like as long as they follow Elixir's  naming rules. The only requirement we need to be sure to fulfill is that the action name matches a route defined in the router.

For example, we could change the action name in the default route that Phoenix gives us in a new app from index:

```elixir
get "/", Test.PageController, :index, as: :pages
```

To test:

```elixir
get "/", Test.PageController, :test, as: :pages
```

As long as we change the action name in the PageController to "test" as well, the welcome page will load as before.

```elixir
def test(conn, _params) do
 render conn, "index"
end
```

While we can name our actions whatever we like, there are conventions for action names which we should follow whenever possible. We went over these in the Routing Guide, but we'll take another quick look here.

- index   - renders a list of all items of the given resource type
- show    - renders an individual item by id
- new     - renders a form for creating a new item
- create  - receives params for one new item and saves it in a datastore
- edit    - retrieves and individual item by id and displays it in a form for editing
- update  - receives params for one edited item and saves it to a datastore
- destroy - receives an id for an item to be deleted and deletes it from a datastore

Each of these actions takes two parameters, which will be provided by Phoenix behind the scenes.

The first parameter is always `conn`, a struct which holds information about the request such as the host, path elements, port, query string, and much more. `conn`, comes to Phoenix via Elixir's plug middleware framework. More detailed info about `conn` can be found in plug's documentation, here: http://elixir-lang.org/docs/plug/Plug.Conn.html

The second parameter is `params`. Not surprisingly, this is a map which holds any parameters passed along in the HTTP request. It is a good practice to pattern match against params in the function signature to provide data in a simple package we can pass on to rendering. We saw this in the Adding Pages guide when we added a messenger parameter to our show route.

```elixir
def show(conn, %{"messenger" => messenger}) do
  render conn, "show", messenger: messenger
end
```

In some cases - often in index actions, for instance - we don't care about parameters because our behavior doesn't depend on them. In those cases, we don't use the incoming params, and simply prepend the variable name with an underscore, `_params`. This will keep the compiler from complaining about the unused variable while still keeping the correct arity. We see this in all the actions of the default PageController which Phoenix generates for us.

###Gathering Data
While Phoenix does not ship with it's own data access layer, the Elixir project Ecto provides a very nice solution for those using the Postgres relational database. (Other adapters for Ecto are coming soon.) We cover how to use Ecto in a Phoenix project in the Data Access guide.

Of course, there are many other data access options. Ets and Dets are key value data stores built into OTP. OTP also provides a relational database called mnesia  with it's own query language called QLC. Both Elixir and Erlang also have a number of libraries for working with a wide range of popular data stores.

The data world is your oyster, but we won't be covering these options in the Phoenix Guides.

###Flash Messages

There are times when we need to communicate with users during the course of an action. Maybe there was an error updating a model. Maybe we just want to welcome them back to the application. For this, we have flash messages.

In order to use flash messages, we first alias the `Phoenix.Controller.Flash` module in the controller we want to set messages in.

```elixir
defmodule HelloPhoenix.PageController do
  use Phoenix.Controller
  alias Phoenix.Controller.Flash
. . .
```
Now we can use `Flash.put/3` to set flash messages on `conn` for this request cycle. We could change the `PageController` index action to set a notice and an error.

```elixir
def index(conn, _params) do
  conn
  |> Flash.put(:notice, "Welcome to Phoenix, from a flash notice!")
  |> Flash.put(:error, "Let's pretend we have an error.")
  |> render "index"
end
```

The `Phoenix.Controller.Flash` module is not particular about the keys we use. As long as we are internally consistent, all will be well. "notice", "error", and "alert", however, are common.

In order to see our flash messages, we need to be able to pull them off of the `conn` and display them all in a template/layout. One way to do the first part is with `get_all/2` which takes `conn` and the key we care about and returns a list of values for that key.

Let's put these blocks in our application layout. They are designed to work if we have one or many messages set on each key.

```elixir
<%= for error <- Flash.get_all(@conn, :error) do %>
      <div class="flash_error">
        <div class="row">
          <p><%= error %></p>
        </div>
      </div>
 <% end %>

 <%= for notice <- Flash.get_all(@conn, :notice) do %>
       <div class="flash_notice">
         <div class="row">
           <p><%= notice %></p>
         </div>
       </div>
  <% end %>
 ```

 When we reload the page, our messages should appear.

 Besides `put/3` and `get_all/2`, the `Phoenix.Controller.Flash` module has some other useful functions worth looking into. The doc strings embedded in the source code have examples.

 `persist/2` takes `conn` and a key, and allows us to save flash messages for that key in the session so that they can persist beyond the current request cycle.

 `get/2` also takes `conn` and a key, but only returns a single value.

 `clear/1` takes only `conn` and removes any flash messages in the session.

 `pop_all/2` also takes `conn` and a key, and returns a tuple containing a list of values and `conn`.

### Rendering
Controllers have several ways of rendering content. The simplest is to render some plain text. Phoenix provides the `text/2` function for just this.

Let's say we have a show action which receives an id from the params map, and all we want to do is return some text with the id. For that, we could do the following.

```elixir
def show(conn, %{"id" => id}) do
  text conn, "Showing id #{id}"
end
```
Assuming we had a route for `get "/our_path/:id"` mapped to this show action, going to "/our_path/15" in your browser should display "Showing id 15" as plain text without any HTML.

A step beyond this is rendering pure json. Phoenix provides the `json/2` function for this. The example below used the built-in `JSON.encode!` function.

```elixir
def show(conn, %{"id" => id}) do
  json conn, JSON.encode!(%{id: id})
end
```
If we again visit "our_path/15" in the browser, we should see a block of JSON with the key "id" mapped to the number 15.

```elixir
{
  id: 15
}
```

Phoenix controllers can also render HTML without a template. As you may have already guessed, the `html/2` function does just that. This time, we implement the show action like this.

```elixir
def show(conn, %{"id" => id}) do
  html conn, """
     <html>
       <head>
          <title>Passing an Id</title>
       </head>
       <body>
         <p>You sent in id #{id}></p>
       </body>
     </html>
    """
end
```

Hitting "/our_path/15" this time generates the HTML document as we created the string for in the action, except that the value "15" will be interpolated into the page. Note that what we wrote in the action is not an eex document. It's a multi-line string, so we interpolate the `id` variable like this `#{id}` instead of this `<%= id %>`.

It is worth noting that the `text/2`, `json/2`, and `html/2` functions require neither a Phoenix view, nor a template to render.

The `json/2` function is obviously useful for writing APIs, and the other two may come in handy, but rendering a template into a layout with values we pass in is a very common case.

For this, Phoenix provides the `render/3` function.

Interestingly, `render/3` is defined in the `Phoenix.View` module instead of `Phoenix.Controller`, but it is aliased in `Phoenix.Controller` for convenience.

We have already seen the render function in the "Adding Pages Guide". Our show action there looked like this.

```elixir
defmodule HelloPhoenix.HelloController do
  use Phoenix.Controller

  def show(conn, %{"messenger" => messenger}) do
    render conn, "show", messenger: messenger
  end
end
```

The `render/3` function will derive the name of a template to render from the name of the view it is called from and the basename we pass in. The view must have the same root name as the controller for this to work properly. In this case, that would be `/web/templates/hello/show.html.eex`. `render/3` will also pass the value which the show action received for messenger from the params hash into the template for interpolation.

Rendering does not end with the template, though. By default, the results of the template render will be inserted into a layout, which will also be rendered.

Templates and layouts have their own guide, so we won't spend much time on them here. What we will look at is how to assign a different layout, or none at all, inside a controller action.

### Assigning Layouts

Layouts are just a special subset of templates. They live in `/web/templates/layout`. Phoenix created one for us when we generated our app. It's called `application.html.eex`, and it is the layout into which all templates will be rendered by default.

Since layouts are really just templates, they need a view to render them. This is the `LayoutView` module defined in `/web/views/layout_view.ex`. Since Phoenix generated this view for us, we won't have to create a new one as long as we put the layouts we want to render inside the `/web/templates/layout` directory.

Before we create a new layout, though, let's do the simplest possible thing and render a template with no layout at all.

The `Phoenix.Controller.Connection` module provides the `put_layout/2` function for us to switch layouts with. (Note: in release 0.4.1 and earlier, this was `assign_layout/2`.) This takes `conn` as it's first argument and a string for the basename of the layout we want to render as the second. Another clause of the fuction will match on the atom `:none` for the second argument, and that's how we will render the Phoenix welcome page with no layout at all.

In a freshly generated Phoenix app, edit the index action of the `PageController` module to look like this.

```elixir
def index(conn, params) do
  conn
  |> put_layout(:none)
  |> render "index"
end
 ```
When you start the application and view `http://localhost:4000/`, you should see a very different page, one with no title, logo image, or css styling at all.

Now let's actually create another layout and render the index template into it. As an example, let's say we had a different layout for the admin section of our application which didn't have the logo image. To do this, let's copy the existing `application.html.eex` to a new file `admin.html.eex`. Then remove the line in it that displays the logo.

```elixir
<span class="logo"></span> <!-- remove this line -->
```

Then, pass the basename of the new layout into `put_layout/2` in our index action.

```elixir
def index(conn, params) do
  conn
  |> put_layout("admin")
  |> render "index"
end
 ```

Reload the page, and we should be rendering the admin layout with no logo.

### Overriding Rendering Formats

Rendering HTML through a template is fine, but what if we need to change the rendering format on the fly? Let's say that sometimes we need HTML, sometimes we need plain text, and sometimes we need JSON. Then what?

Phoenix allows us to change formats on the fly with the `format` query string parameter. To make this  happen, Phoenix requires an appropriately named view and an appropriately named template in the correct directory.

Let's take the `PageController` index action from a newly generated app as an example. Out of the box, this has the right view, `PageView`, the right templates directory, `/web/templates/page`, and the right template for rendering HTML, `application.html.eex`.

```elixir
def index(conn, _params) do
  render conn, "index"
end
```

What it doesn't have is a new template for rendering text. Let's add one at `/web/templates/page/index.txt.eex`.

There are two things to note about this. The first is that even though we will call it with `?format=text`, we need to shorten "text" in the template name to "txt".

The second is that we need to have a compilable template. That would be eex by default. Without the `.eex` file extension, Phoenix will not recognize that a text template exists, and it will complain if we try to use it.

Here is our example `index.txt.eex` template.

```elixir
"OMG, this is actually some text."
```
If we go to `http://localhost:4000/?format=text`, we will see "OMG, this is actually some text."

Of course, we can pass data into our template as well. Let's change our action to take in a message parameter.

```elixir
def index(conn, params) do
  render conn, "index", message: params["message"]
end
```

And let's add a bit to out text template.

```elixir
"OMG, this is actually some text." <%= @message %>
```
Now if we go to `http://localhost:4000/?format=text&message=CrazyTown`, we will see "OMG, this is actually some text. CrazyTown"

### Setting Content Type

Analogous to the `format` query string param, we can render any sort of format we want by modifying the accepts headers and providing the appropriate template. If we wanted to render an xml version of our index action, we might implement the action like this.

```elixir
def index(conn, _params) do
  conn
  |> put_resp_content_type("text/xml")
  |> render "index", content: some_xml_content
end
```
We would then need to provide an `index.xml.eex` template which created valid xml, and we would be done.

For a list of valid content mime-types, please see the documentation from the plug middleware framework: https://github.com/elixir-lang/plug/blob/master/lib/plug/mime.types

##TODO

### Redirection
- Examples
  - redirect conn, "http://elixir-lang.org"
  - redirect conn, 404, "http://elixir-lang.org"

### Assign Conn Properties
- set HTTP status code

### Creating a Custom Errors Controller
- error handling, 404, 500
  - override default config
  - new controller
  - new view
  - new templates
