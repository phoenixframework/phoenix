One common task for web applications is uploading files. These files might be images, videos, PDFs, or files of any other type. In order to upload files through an HTML interface, we need a `file` input tag in a multipart form.

Plug provides a `Plug.Upload` struct to hold the data from the `file` input. A `Plug.Upload` struct will automatically appear in our request parameters if a user has selected a file when they submit the form.

Let's take this one piece at a time.

In the [`Ecto Models Guide`](http://www.phoenixframework.org/docs/ecto-models), we generated an HTML resource for users. We can reuse the form we generated there in order to demonstrate how file uploads work in Phoenix. Please see that guide for instructions on generating the users resource we'll be using here.

The first thing we need to do is change our form into a multipart form. The `form_for/4` function accepts a keyword list of options where we can specify this.

Here is the form from `web/templates/user/form.html.eex` with that change in place.

```elixir
<%= form_for @changeset, @action, [multipart: true], fn f -> %>
. . .
```

Once we have a multipart form, we need a `file` input. Here's how we would do that, also in `form.html.eex`.

```html
. . .
  <div class="form-group">
    <label>Photo</label>
    <%= file_input f, :photo, class: "form-control" %>
  </div>

  <div class="form-group">
    <%= submit "Submit", class: "btn btn-primary" %>
  </div>
<% end %>
```

When rendered, here's what the HTML for that input looks like.

```html
<div class="form-group">
  <label>Photo</label>
  <input class="form-control" id="user_photo" name="user[photo]" type="file">
</div>
```

Note the `name` attribute of our `file` input. This will create the `"photo"` key in the `user_params` map which will be available in our controller action.

That's it from the form side. Now when users submit the form, a `POST` request will route to our `HelloPhoenix.UserController` `create/2` action.

> Note: This photo input does not need to be part of our model for it to come across in the `user_params`. If we want to persist any properties of the photo in a database, however, we would need to add it to our `HelloPhoenix.User` model's schema.

Before we begin, let's add `IO.inspect user_params` to the top of our `HelloPhoenix.create/2` action in `web/controllers/user_controller.ex`. This will show the `user_params` in our development log so we can better see what's happening.

```elixir
. . .
  def create(conn, %{"user" => user_params}) do
    IO.inspect user_params
. . .
```

Since we generated an HTML resource, we can now start our server with `mix phoenix.server`, visit [http://localhost:4000/users/new](http://localhost:4000/users/new), and create a new user with a photo.

When we do that, this is what our `user_params` look like in the log.

```elixir
%{"bio" => "Guitarist", "email" => "dweezil@example.com", "name" => "Dweezil Zappa", "number_of_pets" => "3",
"photo" => %Plug.Upload{content_type: "image/jpg", filename: "cute-kitty.jpg", path: "/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/multipart-558399-917557-1"}}
```

We have a "photo" key which maps to the pre-populated `Plug.Upload` struct representing our uploaded photo.

To make this easier to read, let's just focus on the struct itself.

```elixir
%Plug.Upload{content_type: "image/jpg", filename: "cute-kitty.jpg", path: "/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/multipart-558399-917557-1"}
```

`Plug.Upload` provides the file's content type, original filename, and path to the temporary file which Plug created for us. In our case, `"/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/"` is the directory which Plug created to put uploaded files in. It will persist across requests. `"multipart-558399-917557-1"` is the name Plug gave to our uploaded file. If we had multiple `file` inputs and if the user selected photos for all of them, we would have multiple files in this directory. Plug will make sure all the filenames are unique.

> Note: This file is temporary, and Plug will remove it from the directory as the request completes. If we need to do anything with this file, we need to do it before then.

Once we have the `Plug.Upload` struct available in our controller, we can perform any operation on in we want. We can check to make sure the file exists with `File.exists?/1`, copy it somewhere else on the filesystem with `File.cp/2`, send it to S3 with an external library, or even send it back to the client with [Plug.Conn.send_file/5](http://hexdocs.pm/plug/Plug.Conn.html#send_file/5).

There's one last thing to note about file uploads. Let's create another user, this time without selecting a photo.

With no data from the `file` input, we get neither the "photo" key nor a `Plug.Upload` struct. Here are the `user_params` from the log.

```elixir
%{"bio" => "Guitarist", "email" => "dweezil@example.com", "name" => "Dweezil Zappa", "number_of_pets" => "3"}
```

## Configuring upload limits

The conversion from the data being sent by the form to an actual `Plug.Upload` is done by the `Plug.Parsers` plug which we can find inside `HelloPhoenix.Endpoint`:

```elixir
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Poison
```

Besides the options above, `Plug.Parsers` accepts other options to control data upload:

  * `:length` - sets the max body length to read, defaults to `8_000_000` bytes
  * `:read_length` - set the amount of bytes to read at one time, defaults to `1_000_000` bytes
  * `:read_timeout` - set the timeout for each chunk received, defaults to `15_000` ms

The first option configures the maximum data allowed. The remaining ones configure how much data we expect to read and its frequency. If the client cannot push data fast enough, the connection will be terminated. Phoenix ships with reasonable defaults but you may want to customize it under special circumnstances, for example, if you are expecting really slow clients to send large chunks of data.

It is also worth pointing out those limits are important as a security mechanism. For example, if we don't set a limit for data upload, attackers could open up thousands of connections to your application and send one byte every 2 minutes, which would take very long to complete while using up all connections to your server. The limits above expect at least a reasonable amount of progress, making attackers' lives a bit harder.
