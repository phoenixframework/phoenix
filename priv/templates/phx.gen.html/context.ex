defmodule <%= inspect context.module %> do
  @moduledoc """
  The boundary for the <%= schema.human_singular %> system.
  """
  import Ecto.{Query, Changeset}, warn: false
  alias <%= inspect schema.repo %>
end
