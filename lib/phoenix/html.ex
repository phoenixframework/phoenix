defmodule Phoenix.HTML do
  @moduledoc """
  Conveniences for working HTML strings and templates.

  When used, it imports this module and, in the future,
  many other modules under the Phoenix.HTML namespace.

  ## HTML Safe

  One of the main responsibilities of this module is to
  provide convenience functions for escaping and marking
  HTML code as safe or unsafe.

  In order to mark some code as safe, developers should
  simply wrap their IO data in a `{:safe, data}` tuple.
  Alternative, one can simply use the `safe/1` function.
  """

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.HTML
    end
  end

  @doc """
  Marks the given value as HTML safe.
  """
  def safe({:safe, value}), do: {:safe, value}
  def safe(value) when is_binary(value), do: {:safe, value}

  @doc """
  Escapes the HTML entities in the given string.
  """
  def html_escape(buffer) when is_binary(buffer) do
    IO.iodata_to_binary(for <<char <- buffer>>, do: escape_char(char))
  end

  @compile {:inline, escape_char: 1}

  @escapes [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  Enum.each @escapes, fn { match, insert } ->
    defp escape_char(unquote(match)), do: unquote(insert)
  end

  defp escape_char(char), do: << char >>
end
