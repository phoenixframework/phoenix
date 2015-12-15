defmodule Phoenix.Endpoint.Handler do
  @moduledoc """
  API for exporting webserver plug adapter child spec

  A handler will need to implement a child_spec/3
  function which takes

    * the schme of the endpoint :http or :https
    * phoenix top-most endpoint module
    * phoenix app configuration for the specified scheme

  it has to return a child_spec
  """
  use Behaviour

  @doc """
  provides the children specification to be passed
  to Phoenix.Endpoint.Server supervisor
  """
  @callback child_spec(scheme :: atom, endpoint :: module, config :: Keyword.t) :: Supervisor.Spec.spec

end
