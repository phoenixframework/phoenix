defmodule MyApp.Views do
  @templates_root Path.join([__DIR__, "../../fixtures/templates"])

  defmacro __using__(_options \\ []) do
    quote do
      use Phoenix.View, templates_root: unquote(@templates_root)
      import unquote(__MODULE__)
    end
  end
end
