defmodule Phoenix.Integration.HTTPClient do
  @doc """
  Performs HTTP Request and returns Response

    * method - The http method, for example :get, :post, :put, etc
    * url - The string url, for example "http://example.com"
    * headers - The map of headers
    * body - The optional string body. If the body is a map, it is converted
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
    ct_type = headers["content-type"] |> String.to_char_list

    header = Enum.map headers, fn {k, v} ->
      {String.to_char_list(k), String.to_char_list(v)}
    end

    case method do
      :get -> :httpc.request(:get, {url, header}, [], body_format: :binary)
      _    -> :httpc.request(method, {url, header, ct_type, body}, [], body_format: :binary)
    end |> format_resp
  end

  defp format_resp({:ok, {{_http, status, _status_phrase}, headers, body}}) do
    {:ok, %{status: status, headers: headers, body: body}}
  end
  defp format_resp({:error, reason}), do: {:error, reason}
end
