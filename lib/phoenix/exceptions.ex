defmodule Phoenix.NotAcceptableError do
  @moduledoc """
  Raised when one of `accept*` headers are not accepted by the server.

  This exception is commonly raised by `Phoenix.Controller.accepts/2`
  which negotiates the media types the server is able to serve with
  the contents the client are able to render.

  If you are seeing this error, you should check if you are listing
  the desired formats in your `:accepts` plug or if you are setting
  the proper accept header in the client.
  """

  defexception message: nil, plug_status: 406
end
