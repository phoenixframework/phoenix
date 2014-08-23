defmodule Phoenix.Controller.Action do
  import Phoenix.Controller.Connection
  import Plug.Conn
  alias Phoenix.Config

  @moduledoc """
  Carries out Controller action after successful Router match and handles
  404 and 500 responses after route match
  """

  @doc """
  Performs Controller action, invoking the "2nd layer" Plug stack.

  Connection query string parameters are fetched automatically before
  controller actions are called, as well as merging any named parameters from
  the route definition.
  """
  def perform(conn, controller, action, named_params) do
    conn = assign_private(conn, :phoenix_named_params, named_params)
    |> assign_private(:phoenix_action, action)
    |> assign_private(:phoenix_controller, controller)

    apply(controller, :call, [conn, []])
  end

  @doc """
  Handles sending 404 response based on Router's Mix Config settings

  ## Router Configuration Options

    * page_controller - The optional Module to have `not_found/2` action invoked
                        when 404's status occurs.
                        Default `Phoenix.Controller.PageController`
    * debug_errors - Bool to display Phoenix's route debug page for 404 status.
                     Default `false`

  """
  def handle_not_found(conn) do
    conn   = put_in conn.halted, false
    router = router_module(conn)
    params = named_params(conn)

    if Config.router(router, [:debug_errors]) do
      perform conn, Phoenix.Controller.PageController, :not_found_debug, params
    else
      perform conn, Config.router!(router, [:page_controller]), :not_found, params
    end
  end


  @doc """
  Handles sending 500 response based on Router's Mix Config settings

  ## Router Configuration Options

    * page_controller - The optional Module to have `error/2` action invoked
                        when 500's status occurs.
                        Default `Phoenix.Controller.PageController`
    * debug_errors - Bool to display Phoenix's route debug page for 500 status.
                     Default `false`

  """

  def handle_error(conn) do
    conn   = put_in conn.halted, false
    router = router_module(conn)
    params = named_params(conn)

    if Config.router(router, [:debug_errors]) do
      perform conn, Phoenix.Controller.PageController, :error_debug, params
    else
      perform conn, Config.router!(router, [:page_controller]), :error, params
    end
  end
end
