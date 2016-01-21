defmodule Phoenix.Endpoint.Handler do
  @moduledoc """
  API for exporting a webserver.

  A handler will need to implement a `child_spec/3`
  function which takes:

    * the scheme of the endpoint :http or :https
    * phoenix top-most endpoint module
    * phoenix app configuration for the specified scheme

  it has to return a child_spec.
  """

  @doc """
  Provides the children specification to be passed
  to `Phoenix.Endpoint.Server` supervisor.
  """
  @callback child_spec(scheme :: atom, endpoint :: module, config :: Keyword.t) :: Supervisor.Spec.spec
end
