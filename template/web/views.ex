defmodule <%= application_module %>.Views do

  defmacro __using__(_options) do
    quote do
      use Phoenix.View
      import unquote(__MODULE__)

      # This block is expanded within all views for aliases, imports, etc
      alias <%= application_module %>.Views

      import <%= application_module %>.I18n
    end
  end

  # Functions defined here are available to all other views/templates
end


