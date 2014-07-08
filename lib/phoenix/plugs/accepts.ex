defmodule Phoenix.Plugs.Accepts do
  import Phoenix.Controller.Connection
  alias Phoenix.Mime

  @moduledoc """
  Plug to handle which Accept headers a Plug stack accepts.
  Unaccepted mime-types will return a 400 Bad Request response

  Plugged automatically by Phoenix.Controller

  Examples

  plug Phoenix.Plugs.Accepts, ["html", "json"]

  """

  def init(opts), do: opts

  def call(conn, extensions) do
    primary_accept_extension = Mime.ext_from_type(response_content_type(conn))

    if primary_accept_extension in extensions do
      conn
    else
      halt!(conn)
    end
  end
end
