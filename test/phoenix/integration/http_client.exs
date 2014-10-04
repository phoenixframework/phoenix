defmodule Phoenix.Integration.HTTPClient do

  @moduledoc """
  Simple HTTP client for integration testing
  """

  defmodule Response, do: defstruct(status: nil, headers: [], body: nil)

  @doc """
  Performs HTTP Request and returns Response

  ## Examples

      iex> HTTPClient.request(:get, "http://127.0.0.1", %{})
      {:ok, %Response{..})

      iex> HTTPClient.request(:post, "http://127.0.0.1", %{}, param1: "val1")
      {:ok, %Response{..})

      iex> HTTPClient.request(:get, "http://unknownhost", %{}, param1: "val1")
      {:error, ...}

  """
  def request(method, url, opts, body \\ "")
  def request(method, url, opts, body) when is_map body do
    request(method, url, opts, URI.encode_query(body))
  end
  def request(method, url, opts, body) do
    url     = String.to_char_list(url)
    headers = Dict.get(opts, :headers, %{})
    |> Dict.put_new("content-type", "text/html")
    |> Enum.map(fn {k, v} -> {String.to_char_list(k), String.to_char_list(v)} end)

    case method do
      :get -> :httpc.request(:get, {url, headers}, [], body_format: :binary)
      meth -> :httpc.request(meth, {url, headers, headers["content-type"], body}, [],
                             body_format: :binary)
    end |> format_resp
  end
  defp format_resp({:ok, {{_httpvs, status, _status_phrase}, headers, body}}) do
    {:ok, %Response{status: status, headers: headers, body: body}}
  end
  defp format_resp({:error, reason}), do: {:error, reason}
end

