# File Uploads

One common task for web applications is uploading files. These files might be images, videos, PDFs, or files of any other type. In order to upload files through an HTML interface, we need a `file` input tag in a multipart form.

> #### Looking for the LiveView Uploads guide? {: .neutral}
>
> This guide explains multipart HTTP file uploads via `Plug.Upload`.
> For more information about LiveView file uploads, including direct-to-cloud external uploads on
> the client, refer to the [LiveView Uploads guide](https://hexdocs.pm/phoenix_live_view/uploads.html).

Plug provides a `Plug.Upload` struct to hold the data from the `file` input. A `Plug.Upload` struct will automatically appear in your request parameters if a user has selected a file when they submit the form.

In this guide you will do the following:

  1.  Configure a multipart form

  2. Add a file input element to the form

  3. Verify your upload params

  4. Manage your uploaded files

In the [`Contexts guide`](contexts.md), we generated an HTML resource for products. We can reuse the form we generated there in order to demonstrate how file uploads work in Phoenix. Please refer to that guide for instructions on generating the product resource you will be using here.

### Configure a multipart form

The first thing you need to do is change your form into a multipart form. The `HelloWeb.CoreComponents` `simple_form/1` component accepts a `multipart` attribute where you can specify this.

Here is the form from `lib/hello_web/controllers/product_html/product_form.html.heex` with that change in place:

```heex
<.simple_form :let={f} for={@changeset} action={@action} multipart>
. . .
```

### Add a file input

Once you have a multipart form, you need a `file` input. Here's how you would do that, also in `product_form.html.heex`:

```heex
. . .
  <.input field={f[:photo]} type="file" label="Photo" />

  <:actions>
    <.button>Save Product</.button>
  </:actions>
</.simple_form>
```

When rendered, here is the HTML for the default `HelloWeb.CoreComponents` `input/1` component:

```html
<div>
  <label for="product_photo" class="block text-sm...">Photo</label>
  <input type="file" name="product[photo]" id="product_photo" class="mt-2 block w-full...">
</div>
```

Note the `name` attribute of your `file` input. This will create the `"photo"` key in the `product_params` map which will be available in your controller action.

This is all from the form side. Now when users submit the form, a `POST` request will route to your `HelloWeb.ProductController` `create/2` action.

> #### Should I add photo to my Ecto schema? {: .neutral}
>
> The photo input does not need to be part of your schema for it to come across in the `product_params`. If you want to persist any properties of the photo in a database, however, you would need to add it to your `Hello.Product` schema.

### Verify your upload params

Since you generated an HTML resource, you can now start your server with `mix phx.server`, visit [http://localhost:4000/products/new](http://localhost:4000/products/new), and create a new product with a photo.

Before you begin, add `IO.inspect product_params` to the top of your `ProductController.create/2` action in `lib/hello_web/controllers/product_controller.ex`. This will show the `product_params` in your development log so you can get a better sense of what's happening.

```elixir
. . .
  def create(conn, %{"product" => product_params}) do
    IO.inspect product_params
. . .
```

When you do that, this is what your `product_params` will output in the log:

```elixir
%{"title" => "Metaprogramming Elixir", "description" => "Write Less Code, Get More Done (and Have Fun!)", "price" => "15.000000", "views" => "0",
"photo" => %Plug.Upload{content_type: "image/png", filename: "meta-cover.png", path: "/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/multipart-558399-917557-1"}}
```

You have a `"photo"` key which maps to the pre-populated `Plug.Upload` struct representing your uploaded photo.

To make this easier to read, focus on the struct itself:

```elixir
%Plug.Upload{content_type: "image/png", filename: "meta-cover.png", path: "/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/multipart-558399-917557-1"}
```

`Plug.Upload` provides the file's content type, original filename, and path to the temporary file which Plug created for you. In this case, `"/var/folders/_6/xbsnn7tx6g9dblyx149nrvbw0000gn/T//plug-1434/"` is the directory created by Plug in which to put uploaded files. The directory will persist across requests. `"multipart-558399-917557-1"` is the name Plug gave to your uploaded file. If you had multiple `file` inputs and if the user selected photos for all of them, you would have multiple files scattered in temporary directories. Plug will make sure all the filenames are unique.

> #### Plug.Upload files are temporary {: .info}
>
> Plug removes uploads from its directory as the request completes. If you need to do anything with this file, you need to do it before then (or [give it away](`Plug.Upload.give_away/3`), but that is outside the scope of this guide).

### Manage your uploaded files

Once you have the `Plug.Upload` struct available in your controller, you can perform any operation on it you want. For example, you may want to do one or more of the following:

* Check to make sure the file exists with `File.exists?/1`

* Copy the file somewhere else on the filesystem with `File.cp/2`

* Give the file away to another Elixir process with `Plug.Upload.give_away/3`

* Send it to S3 with an external library

* Send it back to the client with `Plug.Conn.send_file/5`

In a production system, you may want to copy the file to a root directory, such as `/media`. When doing so, it is important to guarantee the names are unique. For instance, if you are allowing users to upload product cover images, you could use the product id to generate a unique name:

```elixir
if upload = product_params["photo"] do
  extension = Path.extname(upload.filename)
  File.cp(upload.path, "/media/#{product.id}-cover#{extension}")
end
```

Then a `Plug.Static` plug could be added in your `lib/my_app_web/endpoint.ex` to serve the files at `"/media"`:

```elixir
plug Plug.Static, at: "/uploads", from: "/media"
```

The uploaded file can now be accessed from your browsers using a path such as `"/uploads/1-cover.jpg"`. In practice, there are other concerns you want to handle when uploading files, such validating extensions, encoding names, and so on. Many times, using a library that already handles such cases is preferred.

Finally, notice that when there is no data from the `file` input, you get neither the `"photo"` key nor a `Plug.Upload` struct. Here are the `product_params` from the log.

```elixir
%{"title" => "Metaprogramming Elixir", "description" => "Write Less Code, Get More Done (and Have Fun!)", "price" => "15.000000", "views" => "0"}
```

## Configuring upload limits

The conversion from the data being sent by the form to an actual `Plug.Upload` is done by the `Plug.Parsers` plug which you can find inside `HelloWeb.Endpoint`:

```elixir
# lib/hello_web/endpoint.ex
plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"],
  json_decoder: Phoenix.json_library()
```

Besides the options above, `Plug.Parsers` accepts other options to control data upload:

  * `:length` - sets the max body length to read, defaults to `8_000_000` bytes
  * `:read_length` - set the amount of bytes to read at one time, defaults to `1_000_000` bytes
  * `:read_timeout` - set the timeout for each chunk received, defaults to `15_000` ms

The first option configures the maximum data allowed. The remaining ones configure how much data we expect to read and its frequency. If the client cannot push data fast enough, the connection will be terminated. Phoenix ships with reasonable defaults but you may want to customize it under special circumstances, for example, if you are expecting really slow clients to send large chunks of data.

It is also worth pointing out those limits are important as a security mechanism. For example, if you don't set a limit for data upload, attackers could open up thousands of connections to your application and send one byte every 2 minutes, which would take very long to complete while using up all connections to your server. The limits above expect at least a reasonable amount of progress, making attackers' lives a bit harder.
