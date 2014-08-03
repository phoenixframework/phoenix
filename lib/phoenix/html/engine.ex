defmodule Phoenix.Html.Engine do
  use EEx.Engine
  alias Phoenix.Html
  alias Phoenix.Html.Safe

  def handle_body(body), do: Html.safe(body)

  def handle_text(buffer, text) do
    quote do
      {:safe, unquote(Html.unsafe(buffer)) <> unquote(text)}
    end
  end

  def handle_expr(buffer, "=", expr) do
    expr   = expr(expr)
    buffer = Html.unsafe(buffer)

    {:safe, quote do
      buff = unquote(buffer)
      buff <> (case unquote(expr) do
        {:safe, bin} when is_binary(bin) -> bin
        bin when is_binary(bin) -> Html.escape(bin)
        other -> Safe.to_string(other)
      end)
    end}
  end

  def handle_expr(buffer, "", expr) do
    expr   = expr(expr)
    buffer = Html.unsafe(buffer)

    quote do
      buff = unquote(buffer)
      unquote(expr)
      buff
    end
  end

  defp expr(expr) do
    Macro.prewalk(expr, &EEx.Engine.handle_assign/1)
  end
end

