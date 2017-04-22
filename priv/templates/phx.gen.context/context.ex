defmodule <%= inspect context.module %> do
  @moduledoc """
  The boundary for the <%= context.name %> system.
  """

  import Ecto.Query, warn: false
  alias <%= inspect schema.repo %>
end
