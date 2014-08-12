defmodule Phoenix.Template.Engine do
  use Behaviour

  @moduledoc """
  Engines need only to support precompiling a template function, of the form:

      def precompile(file_path, template_name)

  The `precompile/2` function must return an AST for for a `render/2` function:

      def render(template_name, assigns \\ [])

  See `Template.EExEngine` for an example engine implementation.


  ## Template Engine Configuration

  By default, `eex` and `haml` are supported (with an optional `Calliope` dep)
  To Configure a third-party Phoenix Template Engine, simply add the
  extenion and module to your Mix Config, ie:

      config :phoenix, :template_engines,
        slim: Slim.PhoenixEngine

  """

  defcallback precompile(file_path :: binary, template_name :: binary) :: term

end
