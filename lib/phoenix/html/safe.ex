defprotocol Phoenix.HTML.Safe do
  @moduledoc """
  Defines the HTML safe protocol.

  In order to promote HTML safety, Phoenix templates
  do not use `Kernel.to_string/1` to convert data types to
  strings in templates. Instead, Phoenix uses this
  protocol which must be implemented by data structures
  and guarantee that a HTML safe representation is returned.

  Furthermore, this protocol relies on iodata, which provides
  better performance when sending or streaming data to the client.
  """

  def to_iodata(data)
end

defimpl Phoenix.HTML.Safe, for: Atom do
  def to_iodata(nil),  do: ""
  def to_iodata(atom), do: Phoenix.HTML.Safe.BitString.to_iodata(Atom.to_string(atom))
end

defimpl Phoenix.HTML.Safe, for: BitString do
  def to_iodata(data) when is_binary(data) do
    IO.iodata_to_binary(for <<char <- data>>, do: escape_char(char))
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

  defp escape_char(char), do: char
end

defimpl Phoenix.HTML.Safe, for: List do
  def to_iodata([h|t]) do
    [to_iodata(h)|to_iodata(t)]
  end

  def to_iodata([]) do
    []
  end

  def to_iodata(?<), do: "&lt;"
  def to_iodata(?>), do: "&gt;"
  def to_iodata(?&), do: "&amp;"
  def to_iodata(?"), do: "&quot;"
  def to_iodata(?'), do: "&#39;"

  def to_iodata(h) when is_integer(h) do
    h
  end

  def to_iodata(h) when is_binary(h) do
    Phoenix.HTML.Safe.BitString.to_iodata(h)
  end

  def to_iodata({:safe, data}) do
    data
  end
end

defimpl Phoenix.HTML.Safe, for: Integer do
  def to_iodata(data), do: Integer.to_string(data)
end

defimpl Phoenix.HTML.Safe, for: Float do
  def to_iodata(data) do
    IO.iodata_to_binary(:io_lib_format.fwrite_g(data))
  end
end

defimpl Phoenix.HTML.Safe, for: Tuple do
  def to_iodata({:safe, data}), do: data
end
