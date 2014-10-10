## Views

The Phoenix view layer is composed of two main components. There is the application view, which serves as the base for all the other views. This is where application-wide view behavior goes. There is also a directory of user defined views, each of which acts as a link between a specific controller and it's related templates.

Views have two main jobs to perform, to render templates - including layouts - and to provide functions for transforming raw data into something templates can easily consume.

### Main Application View

The application view Phoenix generates in a new application lives at `/web/views.ex`. Let's take a look at it.

```elixir
defmodule HelloPhoenix.Views do

  defmacro __using__(_options) do
    quote do
      use Phoenix.View
      import unquote(__MODULE__)

      # This block is expanded within all views for aliases, imports, etc
      import HelloPhoenix.I18n
      import HelloPhoenix.Router.Helpers
      alias Phoenix.Controller.Flash
    end
  end

  # Functions defined here are available to all other views/templates
end
```
That first macro definition for `__using__/1` might not look very familiar at first, but it's actually straight-forward. The idea is to bundle together all the needed `use/1`, `import/1`, and `alias/1` calls in one place so that another view module can pull in all that code and behavior with one single line `use HelloPhoenix.Views`.

Our page view does that, and all our user-defined views should as well.

```elixir
defmodule HelloPhoenix.PageView do
  use HelloPhoenix.Views

end
```
We can use, import, or alias any other modules we may need in the `__using__/1` macro, and they will be available to all of our views.

In the introduction, we mentioned that views can define functions which take raw data and transform it into something a template can easily use. We can put any such functions that might be needed by multiple views across our application where the comment instructs us to.

What might a real world example look like? Let's say we have users in our system which are represented by Ecto models. User names are commonly broken up in different columns in a database - a first_name, optionally a middle_name, and a last_name.

The application, however, may need to present the user's full name. We could do this by concatenating the values of those fields into a single string in each template that needs it. It's much cleaner, however, to do something like this.

```elixir
<p>Full Name <%= full_name(user) %></p>
```
Let's say that there are a number of templates which will need the user's full name, and that a different view renders each of them. The way to handle that is to define a `full_name/1` function in the appication view.

```elixir
defmodule Test.Views do

  defmacro __using__(_options) do
    quote do
      use Phoenix.View
      import unquote(__MODULE__)

      # This block is expanded within all views for aliases, imports, etc
      import Test.I18n
      import Test.Router.Helpers
      alias Phoenix.Controller.Flash
    end
  end

  # Functions defined here are available to all other views/templates
  def full_name(user) do
    "#{user.first_name} #{user.middle_name} #{user.last_name}"
  end
end
```

- rendering
  - to string
  - render_within
  - render_layout
  - html safety
  - examples in iex

### Individual Views
- `/web/views/my_view.ex`
- if you come from oop, you might want to think of these as instances of the application view. resist!
  - they include the functions, imports, aliases and such from the application view.
- naming conventions
- purpose in life
  - act as decorators
  - helper functions useful for only one controller/templates group
