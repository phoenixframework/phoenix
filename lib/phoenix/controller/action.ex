defmodule Phoenix.Controller.Action do
  import Phoenix.Controller.Connection
  import Plug.Conn
  alias Phoenix.Config

  @moduledoc """
  Carries out Controller action after successful Router match and handles
  404 and 500 responses after route match
  """

  @doc """
  Handles sending 404 response based on Router's Mix Config settings

  ## Router Configuration Options

    * error_controller - The optional Module to have `not_found/2` action invoked
                        when 404's status occurs.
                        Default `Phoenix.Controller.ErrorController`
    * debug_errors - Bool to display Phoenix's route debug page for 404 status.
                     Default `false`

  """
  def handle_not_found(conn) do
    conn   = put_in conn.halted, false
    router = router_module(conn)

    if Config.router(router, [:debug_errors]) do
      Phoenix.Controller.ErrorController.call(conn, :not_found_debug)
    else
      Config.router!(router, [:error_controller]).call(conn, :not_found)
    end
  end


  @doc """
  Handles sending 500 response based on Router's Mix Config settings

  ## Router Configuration Options

    * error_controller - The optional Module to have `error/2` action invoked
                        when 500's status occurs.
                        Default `Phoenix.Controller.ErrorController`
    * catch_errors - Bool to catch errors at the Router level. Default `true`
    * debug_errors - Bool to display Phoenix's route debug page for 500 status.
                     Default `false`

  """

  def handle_error(conn) do
    conn   = put_in conn.halted, false
    router = router_module(conn)

    if Config.router(router, [:debug_errors]) do
      Phoenix.Controller.ErrorController.call(conn, :error_debug)
    else
      Config.router!(router, [:error_controller]).call(conn, :error)
    end
  end
end
