# 6. FAQ

Here we list frequently asked questions about contexts.

## When to use code generators?

In this guide, we have used code generators for schemas, contexts, controllers, and more. If you are happy to move forward with Phoenix defaults, feel free to rely on generators to scaffold large parts of your application. When using Phoenix generators, the main question you need to answer is: does this new functionality (with its schema, table, and fields) belong to one of the existing contexts or a new one?

This way, Phoenix generators guide you to use contexts to group related functionality, instead of having several dozens of schemas laying around without any structure. And remember: if you're stuck when trying to come up with a context name, you can simply use the plural form of the resource you're creating.

## How do I structure code inside contexts?

You may wonder how to organize the code inside contexts. For example, should you define a module for changesets (such as ProductChangesets) and another module for queries (such as ProductQueries)?

One important benefit of contexts is that this decision does not matter much. The context is your public API, the other modules are private. Contexts isolate these modules into small groups so the surface area of your application is the context and not _all of your code_.

So while you and your team could establish patterns for organizing these private modules, it is also our opinion that it is completely fine for them to be different. The major focus should be on how the contexts are defined and how they interact with each other (and with your web application).

Think about it as a well-kept neighbourhood. Your contexts are houses, you want to keep them well-preserved, well-connected, etc. Inside the houses, they may all be a little bit different, and that's fine.

## Returning Ecto structures from context APIs

As we explored the context API, you might have wondered:

> If one of the goals of our context is to encapsulate Ecto Repo access, why does `create_user/1` return an `Ecto.Changeset` struct when we fail to create a user?

Although Changesets are part of Ecto, they are not tied to the database, and they can be used to map data from and to any source, which makes it a general and useful data structure for tracking field changes, perform validations, and generate error messages.

For those reasons, `%Ecto.Changeset{}` is a good choice to model the data changes between your contexts and your web layer - regardless if you are talking to an API or the database.

Finally, note that your controllers and views are not hardcoded to work exclusively with Ecto either. Instead, Phoenix defines protocols such as `Phoenix.Param` and `Phoenix.HTML.FormData`, which allow any library to extend how Phoenix generates URL parameters or renders forms. Conveniently for us, the `phoenix_ecto` project implements those protocols, but you could as well bring your own data structures and implement them yourself.
