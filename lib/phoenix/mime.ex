defmodule Phoenix.Mime do

  @moduledoc """
  Conversions for transforming extension to mime-type and mime-type to extension
  """
  for line <- File.stream!(Path.join([__DIR__, "mimes.txt"]), [], :line) do
    [type, ext] = line |> String.split("\t") |> Enum.map(&String.strip(&1))

    def ext_from_type(unquote(type)), do: unquote(ext)
    def type_from_ext(unquote(ext)), do: unquote(type)
  end

  @doc """
  Convert extension to matching mime content type

  Examples
  iex> Mime.ext_from_type("text/html")
  ".html"
  """
  def ext_from_type(_type), do: nil

  @doc """
  Convert mime content type to matching file extension

  Examples
  iex> Mime.type_from_ext(".html")
  "text/html"
  """
  def type_from_ext(_ext), do: nil

  @doc """
  Check if a given String mime type is valid

  Examples
  iex> Mime.valid_type?("text/html")
  true
  iex> Mime.valid_type?("unknown/type")
  false
  """
  def valid_type?(type), do: ext_from_type(type) != nil
end
