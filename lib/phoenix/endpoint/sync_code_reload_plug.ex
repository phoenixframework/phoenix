defmodule Phoenix.Endpoint.SyncCodeReloadPlug do
  @moduledoc ~S"""
  Wraps an Endpoint, attempting to sync with Phoenix's code reloader if 
  an exception is raising which indicates that we may be in the middle of a reload.

  We detect this by looking at the raised exception and seeing if it indicates
  that the endpoint is not defined. This indicates that the code reloader may be 
  mid way through a compile, and that we should attempt to retry the request
  after the compile has completed. This is also why this must be implemented in
  a separate module (one that is not recompiled in a typical code reload cycle),
  since otherwise it may be the case that the endpoint itself is not defined.
  """

  @behaviour Plug

  def init({endpoint, opts}), do: {endpoint, endpoint.init(opts)}

  def call(conn, {endpoint, opts}), do: do_call(conn, endpoint, opts, true)

  defp do_call(conn, endpoint, opts, retry?) do
    try do
      endpoint.call(conn, opts)
    rescue
      exception in [UndefinedFunctionError] ->
        case exception do
          %UndefinedFunctionError{module: ^endpoint} when retry? ->
            # Sync with the code reloader and retry once
            Phoenix.CodeReloader.sync()
            do_call(conn, endpoint, opts, false)

          exception ->
            reraise(exception, __STACKTRACE__)
        end
    end
  end
end
