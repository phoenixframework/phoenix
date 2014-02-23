defmodule Phoenix.Controller.Filter do
  defmacro __using__(options) do
    quote do
      use Plug.Builder
      import unquote(__MODULE__)
    end
  end

  defmacro before_action(the_plug, options \\ []) do
    quote do
      plug(unquote(the_plug), unquote(options))
    end
  end
end
