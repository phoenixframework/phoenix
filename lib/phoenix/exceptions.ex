defmodule Phoenix.NotAcceptableError do
  @moduledoc """
  Raised when one of the `accept*` headers is not accepted by the server.

  This exception is commonly raised by `Phoenix.Controller.accepts/2`
  which negotiates the media types the server is able to serve with
  the contents the client is able to render.

  If you are seeing this error, you should check if you are listing
  the desired formats in your `:accepts` plug or if you are setting
  the proper accept header in the client. The exception contains the
  acceptable mime types in the `accepts` field.
  """

  defexception message: nil, accepts: [], plug_status: 406
end

defmodule Phoenix.MissingParamError do
  @moduledoc """
  Raised when a key is expected to be present in the request parameters,
  but is not.

  This exception is raised by `Phoenix.Controller.scrub_params/2` which:

    * Checks to see if the required_key is present (can be empty)
    * Changes all empty parameters to nils ("" -> nil)

  If you are seeing this error, you should handle the error and surface it
  to the end user. It means that there is a parameter missing from the request.
  """

  defexception [:message, plug_status: 400]

  def exception([key: value]) do
    msg = "expected key #{inspect value} to be present in params, " <>
          "please send the expected key or adapt your scrub_params/2 call"
    %Phoenix.MissingParamError{message: msg}
  end
end

defmodule Phoenix.ActionClauseError do
  exception_keys =
    FunctionClauseError.__struct__
    |> Map.keys()
    |> Kernel.--([:__exception__, :__struct__])

  defexception exception_keys

  def message(exception) do
    exception
    |> Map.put(:__struct__, FunctionClauseError)
    |> FunctionClauseError.message()
  end

  def blame(exception, stacktrace) do
    {exception, stacktrace} =
      exception
      |> Map.put(:__struct__, FunctionClauseError)
      |> FunctionClauseError.blame(exception, stacktrace)

    exception = Map.put(exception, :__struct__, __MODULE__)

    {exception, stacktrace}
  end
end

defimpl Plug.Exception, for: Phoenix.ActionClauseError do
  def status(_), do: 400
end
