defmodule Mix.Phoenix.AggregateTemplateSource do
  @moduledoc false

  @callback template_sources() :: [module]

  defmacro __using__(_opts) do
    quote do
      @behaviour Mix.Phoenix.TemplateSource
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @impl true
      def render_template(template_path, assigns) do
        Mix.Phoenix.render_template(template_sources(), template_path, assigns)
      end
    end
  end
end
