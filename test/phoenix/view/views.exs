defmodule Phoenix.UserTest.Views do

  @templates_root Path.join([__DIR__, "templates"])

  defmacro __using__(options \\ []) do
    quote do
      use Phoenix.View, templates_root: unquote(@templates_root)
      alias Phoenix.UserTest.Views
      import unquote(__MODULE__)
    end
  end

  def friendly_name(string), do: String.upcase(string)
end


