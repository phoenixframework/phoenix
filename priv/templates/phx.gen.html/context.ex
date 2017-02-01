defmodule <%= inspect context.module %> do
  @moduledoc """
  The boundary for the <%= schema.human_singular %> system.
  """
  import Ecto.Changeset
  alias <%= inspect schema.repo %>
end
