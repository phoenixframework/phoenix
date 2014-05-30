defmodule Phoenix.UserTest.Views do

  defmacro __using__(_) do
    quote do
      use Phoenix.View
      alias MyApp.Views
      import unquote(__MODULE__)
    end
  end

  def friendly_name(string), do: String.upcase(string)
end


