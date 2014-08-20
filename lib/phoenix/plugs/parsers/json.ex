defmodule Phoenix.Plugs.Parsers.JSON do
  import Plug.Conn
  alias Poison, as: JSON

  @moduledoc """
  Parses JSON request body.
  """

  defmodule ParseError do
    @moduledoc """
    Error raised when the request body is malformed.
    """

    defexception [:message]

    defimpl Plug.Exception do
      def status(_exception), do: 400
    end
  end

  @doc """
  Parses JSON body into `conn.params`

  JSON arrays are parsed into a `"_json"` key to allow proper
  param merging.

  An empty request body is parsed as an empty map.
  """
  def parse(conn, "application", "json", _headers, opts) do
    conn
    |> read_body(opts)
    |> decode
  end
  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  defp decode({:ok, body, conn}) when body in [nil, ""] do
    {:ok, %{}, conn}
  end
  defp decode({:ok, body, conn}) do
    case JSON.decode(body) do
      {:ok, terms} when is_list(terms)->
        {:ok, %{"_json" => terms}, conn}
      {:ok, terms} ->
        {:ok, terms, conn}
      _ ->
        raise ParseError, message: "malformed JSON."
    end
  end
end
