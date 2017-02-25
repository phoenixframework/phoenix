defmodule <%= inspect context.module %> do
  @moduledoc """
  The boundary for the <%= context.name %> system.
  """

  import Ecto.{Query, Changeset}, warn: fals
  alias <%= inspect schema.repo %>
end
