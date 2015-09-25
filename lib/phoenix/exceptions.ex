defmodule Phoenix.MissingParamError do
  @moduledoc """
  Raised when a key is expected to be present in the request parameters,
  but is not.

  This exception is raised by `Phoenix.Controller.scrub_params/2` which:

    * Checks to see if the required_key is present (can be empty)
    * Changes all empty parameters to nils ("" -> nil).

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
  defexception [message: nil, plug_status: 400]

  def exception(opts) do
    controller = Keyword.fetch!(opts, :controller)
    action = Keyword.fetch!(opts, :action)
    msg = "bad request to #{inspect controller}.#{action}, " <>
          "no matching action clause to process request"
    %Phoenix.ActionClauseError{message: msg}
  end
end
