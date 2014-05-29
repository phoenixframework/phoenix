defmodule MyApp.Views do

  defmacro __using__(_) do
    quote do
      use Phoenix.View
      alias MyApp.Views
      import unquote(__MODULE__)
    end
  end

end

