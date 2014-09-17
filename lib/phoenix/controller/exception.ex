defmodule Phoenix.Controller.Exception do
  require Logger
  import Elixir.Exception, only: [format_stacktrace: 1, message: 1]
  alias Phoenix.Controller.Exception

  @moduledoc """
  Formats Plug exceptions and handles Error logging

  ## Logging from Error controllers

      defmodule MyErrorController do
        ...
        def error(conn, _) do
          Phoenix.Controller.Exception.log(conn)
          render conn, "pretty_error_page"
        end

      end

  """

  defstruct status: nil,
            stacktrace: nil,
            stacktrace_formatted: nil,
            exception: nil,
            kind: nil,
            type: nil,
            message: nil

  @doc """
  Returns `Exception` struct from caught conn exception or `:no_exception`

  ## Examples

      iex> Exception.from_conn(conn)
      %Exception{...}

      iex> Exception.from_conn(conn)
      :no_exception

  """
  def from_conn(conn) do
    conn
    |> Phoenix.Controller.Connection.error
    |> from_error
  end
  defp from_error({:throw, err}) do
    stack = System.stacktrace

    %Exception{status: Plug.Exception.status(err),
               stacktrace: stack,
               stacktrace_formatted: format_stacktrace(stack),
               kind: :throw,
               exception: err,
               type: :throw,
               message: inspect(err)}

  end
  defp from_error({kind, err}) do
    stack = System.stacktrace
    excep = case err do
      %{__struct__: _} -> err
      _                -> Elixir.Exception.normalize(kind, err)
    end

    %Exception{status: Plug.Exception.status(err),
               stacktrace: stack,
               stacktrace_formatted: format_stacktrace(stack),
               kind: kind,
               exception: excep,
               type: excep.__struct__,
               message: message(excep)}
  end
  defp from_error(_), do: :no_exception

  @doc """
  Logs the caught conn exception as an error

  ## Examples

      iex> Exception.log(conn)

      iex> exeption = Exception.from_conn(conn)
      iex> Exception.log(exception)

  """
  def log(exception = %Exception{}) do
    Logger.error fn -> """
      **(#{inspect exception.type}) #{exception.message}
      #{exception.stacktrace_formatted}
      """
    end
  end
  def log(conn = %Plug.Conn{}) do
    case from_conn(conn) do
      exception = %Exception{} -> log(exception)
      :no_exception            -> :no_exception
    end
  end
end
