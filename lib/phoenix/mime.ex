defmodule Phoenix.Mime do

  @moduledoc """
  Conversions for transforming extension to mime-type and mime-type to extension
  """
  for line <- File.stream!(Path.join([__DIR__, "mimes.txt"]), [], :line) do
    [type, rest] = line |> String.split("\t") |> Enum.map(&String.strip(&1))
    exts         = String.split(rest, ~r/,\s?/)
    exts_no_dots = Enum.map(exts, &String.lstrip(&1, ?.))

    def exts_from_type(unquote(type)), do: unquote(exts_no_dots)
    def type_from_ext(ext) when ext in unquote(exts ++ exts_no_dots), do: unquote(type)
  end

  @doc """
  Convert extension to matching mime content type

  Examples
  iex> Mime.exts_from_type("text/html")
  ["html"]
  """
  def exts_from_type(_type), do: []

  @doc """
  Returns the frist known extension from mime content type
  """
  def ext_from_type(type), do: exts_from_type(type) |> Enum.at(0)

  @doc """
  Convert mime content type to matching file extension

  Examples
  iex> Mime.type_from_ext(".html")
  "text/html"

  iex> Mime.type_from_ext("html")
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
  def valid_type?(type), do: exts_from_type(type) |> Enum.any?
end
