defmodule Phoenix.Mime do
  @doc """
  Convert extension to matching mime content type

  Examples
  iex> Mime.ext_from_type("text/html")
  ".html"
  """
  def ext_from_type(mime) do
    case Plug.MIME.extensions(mime) do
      [fst|_] -> "." <> fst
      [] -> nil
    end
  end

  @doc """
  Convert mime content type to matching file extension

  Examples
  iex> Mime.type_from_ext(".html")
  "text/html"
  """
  def type_from_ext(<<".", ext :: binary>>), do: type_from_ext(to_string(ext))
  def type_from_ext(ext) do
    case Plug.MIME.type(ext) do
      "application/octet-stream" -> nil
      x -> x
    end
  end

  @doc """
  Check if a given String mime type is valid

  Examples
  iex> Mime.valid_type?("text/html")
  true
  iex> Mime.valid_type?("unknown/type")
  false
  """
  def valid_type?(type) do
    Plug.MIME.valid?(type)
  end
end
