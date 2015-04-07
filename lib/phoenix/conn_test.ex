defmodule Phoenix.ConnTest do
  @doc false
  defmacro __using__(_) do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
    end
  end
end
