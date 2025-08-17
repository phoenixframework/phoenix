# 1. Intro to Contexts

Phoenix guides are broken into several major sections. The main building blocks are outlined under the "Core Concepts" section, where we explored [the request life-cycle](request_lifecycle.html), wired up controller actions through our routers, and learned how Ecto allows data to be validated and persisted. Now it's time to tie it all together by writing web-facing features that interact with our greater Elixir application.

When building a Phoenix project, we are first and foremost building an Elixir application. Phoenix's job is to provide a web interface into our Elixir application. Naturally, we compose our applications with modules and functions, but we often assign specific responsibilities to certain modules and give them names: such as controllers, routers, and live views.

However, the most important part of your web application is often where we encapsulate data access and data validation. We call these modules **contexts**. They often talk to a database, using `Ecto`, or APIs, using an HTTP client such as `Req`. By giving these modules a name, we help developers identify these patterns and talk about them. At the end of the day, contexts are just modules, as are your controllers, views, etc.

If you have used `mix phx.gen.html`, `mix phx.gen.json`, or `mix phx.gen.live`, you have already used contexts. For example, run the following generator in a Phoenix application:

```console
$ mix phx.gen.live Post posts title body:text
```

The command above will output a few files, among them, a `MyApp.Posts.Post` schema in `lib/my_app/posts/post.ex`, which outlines how the resource is represented in the database, and a **context** module named `MyApp.Posts` that encapsulates all the database access to said schema. The `MyApp.Posts` module centralizes all functionality related to posts, instead of scattering logic around controllers, LiveViews, etc.

Contexts are also useful to nest resources. For example, if you are adding comments to your posts, you can colocate their schemas, since comments belong to posts, like this:

```console
$ mix phx.gen.live Posts Comment comments post_id:references:posts body:text
```

The first argument to the generator above is the context module, instructing Phoenix to colocate the comments functionality with posts. There is also a `post_id` attribute which specifies a foreign key reference to the posts table. As your application grows, contexts help you group related schemas, instead of having several dozens of schemas with no insights on how they relate to each other.

Developers may also use contexts to intentionally name parts of their application. For example, `mix phx.gen.auth` requires a context name to be explicitly given. It is often invoked as:

```console
$ mix phx.gen.auth Accounts User users
```

or, using whatever name you prefer, such as:

```console
$ mix phx.gen.auth Identity Client clients
```

The generated `Accounts` (or `Identity`) context will encapsulate all functionality for managing users (or clients) and their tokens. You could, if you wanted, name the context `Users` too, but given account/identity management has well defined name and boundary in most applications, giving it an explicit name makes its purposes clear. And, at the end of the day, they are just plain modules.

In this guide, we will use these ideas to build out our web application. Our goal is to build an ecommerce system where we can showcase products, allow users to add products to their cart, and complete their orders. We will do so by intentionally designing and naming our contexts. Opposite to other Phoenix guides, **these guides are meant to be read in order**.

## Our ecommerce application

Let's start an application from scratch to build our ecommerce, using Phoenix Express. We will call the application `hello`.

For macOS/Ubuntu:

```bash
$ curl https://new.phoenixframework.org/hello | sh
```

For Windows PowerShell:

```bash
curl.exe -fsSO https://new.phoenixframework.org/hello.bat; .\hello.bat
```

If those commands do not work, see the [Installation Guide](installation.html) and then run `mix phx.new`:

```console
$ mix phx.new hello
```

Follow any of the steps printed on the screen and open up the generated `hello` project in your editor.

We are ready to move to the next chapter.
