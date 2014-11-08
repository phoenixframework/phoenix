defmodule Phoenix.Integration.HTTPClient do

  @moduledoc """
  Simple HTTP client for integration testing
  """

  defmodule Response, do: defstruct(status: nil, headers: [], body: nil)

  @doc """
  Performs HTTP Request and returns Response

    * method - The http methid, ie :get, :post, :put, etc
    * url - The string url, ie "http://example.com"
    * headers - The map of headers
    * body - The optional string body. If the body is a map, it is convered
             to a URI encoded string of parameters

  ## Examples

      iex> HTTPClient.request(:get, "http://127.0.0.1", %{})
      {:ok, %Response{..})

      iex> HTTPClient.request(:post, "http://127.0.0.1", %{}, param1: "val1")
      {:ok, %Response{..})

      iex> HTTPClient.request(:get, "http://unknownhost", %{}, param1: "val1")
      {:error, ...}

  """
  def request(method, url, headers, body \\ "")
  def request(method, url, headers, body) when is_map body do
    request(method, url, headers, URI.encode_query(body))
  end
  def request(method, url, headers, body) do
    url     = String.to_char_list(url)
    headers = headers |> Dict.put_new("content-type", "text/html")
    content_type = headers["content-type"] |> String.to_char_list
    header_list = Enum.map headers, fn {k, v} ->
      {String.to_char_list(k), String.to_char_list(v)}
    end

    case method do
      :get -> :httpc.request(:get, {url, header_list}, [], body_format: :binary)
      meth -> :httpc.request(meth, {url, header_list, content_type, body}, [],
                             body_format: :binary)
    end |> format_resp
  end
  defp format_resp({:ok, {{_httpvs, status, _status_phrase}, headers, body}}) do
    {:ok, %Response{status: status, headers: headers, body: body}}
  end
  defp format_resp({:error, reason}), do: {:error, reason}
end
