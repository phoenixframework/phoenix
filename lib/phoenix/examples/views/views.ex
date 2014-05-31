defmodule MyApp.Views do
  use Phoenix.View.Base

  defmacro __using__(_) do
    quote do
      use Phoenix.View
      alias MyApp.Views
      import unquote(__MODULE__)
    end
  end

  def title, do: "Default"
end

