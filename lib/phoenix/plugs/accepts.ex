defmodule Phoenix.Plugs.Accepts do
  import Phoenix.Controller.Connection
  import Plug.Conn
  alias Plug.MIME

  @moduledoc """
  Plug to handle which Accept headers a Plug stack accepts.
  Unaccepted mime-types will return a 400 Bad Request response

  ## Examples

      plug Phoenix.Plugs.Accepts, ["html", "json"]

  """

  def init(opts), do: opts

  def call(conn, extensions) do
    primary_accept_extension = MIME.extensions(response_content_type!(conn)) |> hd

    if primary_accept_extension in extensions do
      conn
    else
      conn |> send_resp(400, "Bad Request") |> halt
    end
  end
end
