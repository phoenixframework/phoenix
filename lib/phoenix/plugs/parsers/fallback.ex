defmodule Phoenix.Plugs.Parsers.Fallback do
  @moduledoc false

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:ok, %{}, conn}
  end
end
