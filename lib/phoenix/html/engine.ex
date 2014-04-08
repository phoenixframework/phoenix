defmodule Phoenix.Html.Engine do
  use EEx.TransformerEngine
  use EEx.AssignsEngine
  alias Phoenix.Html.Safe

  def handle_text(buffer, text) do
    quote do
      { :safe, unquote(buffer) <> unquote(text) }
    end
  end

  def handle_expr(buffer, "=", expr) do
    expr   = transform(expr)
    buffer = unsafe(buffer)

    quote do
      buff = unquote(buffer)
      buff <> Safe.to_string(unquote(expr))
    end
  end

  def handle_expr(buffer, "", expr) do
    expr   = transform(expr)
    buffer = unsafe(buffer)

    quote do
      buff = unquote(buffer)
      unquote(expr)
      buff
    end
  end

  defp unsafe({ :safe, value }), do: value
  defp unsafe(value), do: value
end

