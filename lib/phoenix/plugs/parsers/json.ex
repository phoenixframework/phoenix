defmodule Phoenix.Plugs.Parsers.JSON do
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

  import Plug.Conn
  alias Plug.Conn

  def parse(conn, "application", "json", _headers, opts) do
    {:ok, body, conn} = read_body(conn, opts)
    case Jazz.decode(body) do
      {:ok, terms} ->
        {:ok, terms, conn}
      _ ->
        raise ParseError, message: "malformed JSON."
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end
end
