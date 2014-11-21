defmodule Phoenix.Plugs.CodeReloader do
  @moduledoc """
  A plug that simply calls Phoenix's code reloader
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case Phoenix.CodeReloader.reload! do
      :error ->
        # This should be an error but, if the router fails to compile,
        # the whole error handling mechanism fails too. So we need to
        # decouple error handling from the router exactly in cases the
        # router fails.
        #
        # We could also capture the error, but since we can have multiple
        # errors, we need to explore the best way of showing those.
        #
        # raise RuntimeError, "Compilation failed: output in terminal"

        conn
        |> send_resp(500, "Compilation failed: output in terminal")
        |> halt()
      _ ->
        conn
    end
  end
end

