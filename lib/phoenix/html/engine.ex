defmodule Phoenix.HTML.Engine do
  @moduledoc """
  This is an implementation of EEx.Engine and
  Phoenix format encoder that guarantees templates are
  HTML Safe.
  """

  use EEx.Engine
  alias Phoenix.HTML

  @doc false
  def encode(body), do: {:ok, encode!(body)}

  @doc false
  def encode!({:safe, body}), do: body
  def encode!(other), do: HTML.Safe.to_string(other)

  @doc false
  def handle_body(body), do: HTML.safe(body)

  @doc false
  def handle_text(buffer, text) do
    quote do
      {:safe, unquote(unwrap(buffer)) <> unquote(text)}
    end
  end

  @doc false
  def handle_expr(buffer, "=", expr) do
    expr   = expr(expr)
    buffer = unwrap(buffer)
    {:safe, quote do
      buff = unquote(buffer)
      buff <> unquote(to_safe(expr))
     end}
  end

  @doc false
  def handle_expr(buffer, "", expr) do
    expr   = expr(expr)
    buffer = unwrap(buffer)

    quote do
      buff = unquote(buffer)
      unquote(expr)
      buff
    end
  end

  # We can do the work at compile time
  defp to_safe(literal) when is_binary(literal) or is_atom(literal) or is_number(literal) do
    HTML.Safe.to_string(literal)
  end

  # We can do the work at runtime
  defp to_safe(literal) when is_list(literal) do
    quote do: HTML.Safe.to_string(unquote(literal))
  end

  # We need to check at runtime
  defp to_safe(expr) do
    quote do
      case unquote(expr) do
        {:safe, bin} when is_binary(bin) -> bin
        bin when is_binary(bin) -> HTML.html_escape(bin)
        other -> HTML.Safe.to_string(other)
      end
    end
  end

  defp expr(expr) do
    Macro.prewalk(expr, &EEx.Engine.handle_assign/1)
  end

  defp unwrap({:safe, value}), do: value
  defp unwrap(value), do: value
end

