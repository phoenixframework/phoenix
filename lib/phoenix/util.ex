defmodule Phoenix.Util do
  @moduledoc false

  @doc false
  def singularize(1, plural), do: "1 " <> String.trim_trailing(plural, "s")
  def singularize(amount, plural), do: "#{amount} #{plural}"

  @doc false
  def singularize(1, _plural, singular), do: "1 #{singular}"
  def singularize(amount, plural, _singular), do: "#{amount} #{plural}"
end
