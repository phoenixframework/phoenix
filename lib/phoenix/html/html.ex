defmodule Phoenix.Html do
  alias Phoenix.Html

  @escapes [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  defprotocol Safe do
    def to_string(data)
  end

  defimpl Safe, for: Atom do
    def to_string(nil), do: ""
    def to_string(atom), do: Html.escape(atom_to_binary(atom))
  end

  defimpl Safe, for: BitString do
    def to_string(data) when is_binary(data) do
      Html.escape(data)
    end
  end

  defimpl Safe, for: List do
    def to_string(list) do
      bc data inlist list, do: << Safe.to_string(data) :: binary >>
    end
  end

  defimpl Safe, for: Integer do
    def to_string(data), do: integer_to_binary(data)
  end

  defimpl Safe, for: Float do
    def to_string(data) do
      iolist_to_binary(:io_lib_format.fwrite_g(data))
    end
  end

  defimpl Safe, for: Tuple do
    def to_string({ :safe, data }), do: Kernel.to_string(data)
  end

  def escape(buffer) do
    bc << char >> inbits buffer do
      << escape_char(char) :: binary >>
    end
  end

  Enum.each @escapes, fn { match, insert } ->
    defp escape_char(unquote(match)), do: unquote(insert)
  end

  defp escape_char(char), do: << char >>
end

