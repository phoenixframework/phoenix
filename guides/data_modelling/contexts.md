# 1. Intro to Contexts

Phoenix guides are broken into several major sections. The main building blocks are outlined under the "Core Concepts" section, where we explored [the request life-cycle](request_lifecycle.html), wired up controller actions through our routers, and learned how Ecto allows data to be validated and persisted. Now it's time to tie it all together by writing web-facing features that interact with our greater Elixir application.

When building a Phoenix project, we are first and foremost building an Elixir application. Phoenix's job is to provide a web interface into our Elixir application. Naturally, we compose our applications with modules and functions, but we often assign specific responsibilities to certain modules and give them names: such as controllers, routers, and live views.

However, the most important part of your web application is often where we encapsulate data access and data validation. We call these modules **contexts**. They often talk to a database or APIs. By giving modules that expose and group related data the name **contexts**, we help developers identify these patterns and talk about them. At the end of the day, contexts are just modules, as are your controllers, views, etc.

Overall, think of them as boundaries to decouple and isolate parts of your application. They are not a new concept either. For example, anytime you call Elixir's standard library, be it `Logger.info/1` or `Stream.map/2`, you are accessing different contexts. Internally, Elixir's logger is made of multiple modules, but we never interact with those modules directly. We call the `Logger` module the context, exactly because it exposes and groups all of the logging functionality.

Let's use these ideas to build out our web application. Our goal is to build an ecommerce system where we can showcase products, allow users to add products to their cart, and complete their orders. Opposite to other Phoenix guides, **these guides are meant to be read in order**.

## Our ecommerce application

Let's start an application from scratch to build our ecommerce, using Phoenix Express. We will call the application `hello`.

For macOS/Ubuntu:

```bash
$ curl https://new.phoenixframework.org/hello | sh
```

For Windows PowerShell:

```cmd
> curl.exe -fsSO https://new.phoenixframework.org/hello.bat; .\hello.bat
```

If those commands do not work, see the [Installation Guide](installation.html) and then run `mix phx.new`:

```console
$ mix phx.new hello
```

Follow any of the steps printed on the screen and open up the generated `hello` project in your editor.

We are ready to move to the next chapter.
