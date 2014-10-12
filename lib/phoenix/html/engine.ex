defmodule Phoenix.HTML.Engine do
  @moduledoc """
  This is an imlementation of EEx.Engine that
  guarantees templates are HTML Safe.
  """

  use EEx.Engine
  alias Phoenix.HTML

  def handle_body(body), do: HTML.safe(body)

  def handle_text(buffer, text) do
    quote do
      {:safe, unquote(HTML.unsafe(buffer)) <> unquote(text)}
    end
  end

  def handle_expr(buffer, "=", expr) do
    expr   = expr(expr)
    buffer = HTML.unsafe(buffer)

    {:safe, quote do
      buff = unquote(buffer)
      buff <> (case unquote(expr) do
        {:safe, bin} when is_binary(bin) -> bin
        bin when is_binary(bin) -> HTML.escape(bin)
        other -> HTML.Safe.to_string(other)
      end)
    end}
  end

  def handle_expr(buffer, "", expr) do
    expr   = expr(expr)
    buffer = HTML.unsafe(buffer)

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

