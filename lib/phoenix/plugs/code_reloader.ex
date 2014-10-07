defmodule Phoenix.Plugs.CodeReloader do
  @moduledoc """
  A plug that simply calls Phoenix's code reloader
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    Phoenix.CodeReloader.reload!
    conn
  end
end

