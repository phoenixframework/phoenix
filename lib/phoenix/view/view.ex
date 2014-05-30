defmodule Phoenix.View do

  defmacro __using__(options) do
    quote do
      use Phoenix.Template.Compiler, path: Path.join([__DIR__, "./"])
      import unquote(__MODULE__)
    end
  end

  def safe({:safe, string}), do: {:safe, string}
  def safe(string), do: {:safe, string}

  def unsafe({:unsafe, string}), do: {:unsafe, string}
  def unsafe(string), do: {:unsafe, string}
end

#
# defmodule MyApp.Views do
#
#   defmacro __using__(_) do
#     quote do
#       use Phoenix.View
#       alias MyApp.Views
#       import unquote(__MODULE__)
#     end
#   end
#
# end
#
# defmodule MyApp.Views.Users do
#   use MyApp.Views
#
#   def friendly_name(name), do: ""
# end
#
# Views.Users.render("show.html", [name: "chris"])
