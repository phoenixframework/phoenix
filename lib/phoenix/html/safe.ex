alias Phoenix.HTML

defprotocol Phoenix.HTML.Safe do
  @moduledoc """
  Defines the HTML safe protocol.

  In order to promote HTML safety, Phoenix templates
  do not use `Kernel.to_string/1` to convert data types to
  strings in templates. Instead, Phoenix uses this
  protocol which must be implemented by data structures
  and guarantee that a HTML safe representation is returned.
  """

  def to_string(data)
end

defimpl Phoenix.HTML.Safe, for: Atom do
  def to_string(nil), do: ""
  def to_string(atom), do: HTML.html_escape(Atom.to_string(atom))
end

defimpl Phoenix.HTML.Safe, for: BitString do
  def to_string(data) when is_binary(data) do
    HTML.html_escape(data)
  end
end

defimpl Phoenix.HTML.Safe, for: List do
  def to_string(list) do
    do_to_string(list) |> IO.iodata_to_binary
  end

  defp do_to_string([h|t]) do
    [do_to_string(h)|do_to_string(t)]
  end

  defp do_to_string([]) do
    []
  end

  # TODO: We could inline the escape for integers ?>, ?<,
  # ?&, ?" and ?' instead of calling Phoenix.HTML.html_escape/1
  defp do_to_string(h) when is_integer(h) do
    HTML.html_escape(<<h :: utf8>>)
  end

  defp do_to_string(h) when is_binary(h) do
    HTML.html_escape(h)
  end

  defp do_to_string({:safe, h}) when is_binary(h) do
    h
  end
end

defimpl Phoenix.HTML.Safe, for: Integer do
  def to_string(data), do: Integer.to_string(data)
end

defimpl Phoenix.HTML.Safe, for: Float do
  def to_string(data) do
    IO.iodata_to_binary(:io_lib_format.fwrite_g(data))
  end
end

defimpl Phoenix.HTML.Safe, for: Tuple do
  def to_string({:safe, data}) when is_binary(data), do: data
end
