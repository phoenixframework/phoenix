defmodule Phoenix.PlugError do
  @moduledoc false

  Code.ensure_loaded?(Plug.Conn.WrapperError)
  if function_exported?(Plug.Conn.WrapperError, :reraise, 4) do
    def reraise(_conn, _type, exception) do
      Plug.Conn.WrapperError.reraise(exception)
    end
    def reraise(conn, type, reason, stack) do
      Plug.Conn.WrapperError.reraise(conn, type, reason, stack)
    end
  else
    def reraise(conn, type, exception) do
      Plug.Conn.WrapperError.reraise(conn, type, exception)
    end
    def reraise(conn, type, reason, _stack) do
      Plug.Conn.WrapperError.reraise(conn, type, reason)
    end
  end
end
