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
  def request(method, url, headers, body \\ "", profile \\ nil)
  def request(method, url, headers, body, profile) when is_map body do
    request(method, url, headers, URI.encode_query(body), profile)
  end
  def request(method, url, headers, body, profile) do
    url     = String.to_char_list(url)
    headers = headers |> Map.put_new("content-type", "text/html")
    ct_type = headers["content-type"] |> String.to_char_list

    header = Enum.map headers, fn {k, v} ->
      {String.to_char_list(k), String.to_char_list(v)}
    end

    {:ok, pid} =
      if profile do
        {:ok, profile}
      else
        :inets.start(:httpc, profile: profile())
      end

    resp =
      case method do
        :get -> :httpc.request(:get, {url, header}, [], [body_format: :binary], pid)
        _    -> :httpc.request(method, {url, header, ct_type, body}, [], [body_format: :binary], pid)
      end

    unless profile, do: :inets.stop(:httpc, pid)
    format_resp(resp)
  end

  # Generate a random profile per request to avoid reuse
  def profile() do
    :crypto.strong_rand_bytes(4) |> Base.encode16 |> String.to_atom
  end

  defp format_resp({:ok, {{_http, status, _status_phrase}, headers, body}}) do
    {:ok, %{status: status, headers: headers, body: body}}
  end
  defp format_resp({:error, reason}), do: {:error, reason}
end
