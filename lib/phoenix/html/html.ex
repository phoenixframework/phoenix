defmodule Phoenix.Html do
  alias Phoenix.Html

  @escapes [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  def safe({:safe, value}), do: {:safe, value}
  def safe(value), do: {:safe, value}
  def unsafe({:safe, value}), do: value
  def unsafe(value), do: value

  defprotocol Safe do
    def to_string(data)
  end

  defimpl Safe, for: Atom do
    def to_string(nil), do: ""
    def to_string(atom), do: Html.escape(Atom.to_string(atom))
  end

  defimpl Safe, for: BitString do
    def to_string(data) when is_binary(data) do
      Html.escape(data)
    end
  end

  defimpl Safe, for: List do
    def to_string(list) do
      for data <- list, into: "", do: << Safe.to_string(data) :: binary >>
    end
  end

  defimpl Safe, for: Integer do
    def to_string(data), do: Integer.to_string(data)
  end

  defimpl Safe, for: Float do
    def to_string(data) do
      IO.iodata_to_binary(:io_lib_format.fwrite_g(data))
    end
  end

  defimpl Safe, for: Tuple do
    def to_string({ :safe, data }), do: Kernel.to_string(data)
  end

  def escape(buffer) do
    for << char <- buffer >>, into: "" do
      << escape_char(char) :: binary >>
    end
  end

  Enum.each @escapes, fn { match, insert } ->
    defp escape_char(unquote(match)), do: unquote(insert)
  end

  defp escape_char(char), do: << char >>
end

