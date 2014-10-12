defmodule Phoenix.Template.Engine do
  @moduledoc """
  Specifies the API for adding custom template engines into Phoenix.

  Engines need only to implement the `compile/2` function, that receives
  the template file and the template name and outputs the template quoted
  expression:

      def compile(file, template)

  See `Phoenix.Template.EExEngine` for an example engine implementation.
  """

  use Behaviour

  defcallback compile(file :: binary, template :: binary) :: Macro.t
end
