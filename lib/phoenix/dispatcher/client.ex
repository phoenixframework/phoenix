defmodule Phoenix.Dispatcher.Client do
  alias Phoenix.Dispatcher.Server

  def start(request) do
    :gen_server.start(Server, {self, request}, [])
  end

  def dispatch(pid) do
    :gen_server.cast(pid, :dispatch)
    receive do
      {:ok, conn}            -> {:ok, conn}
      {:error, conn, reason} -> {:error, conn, reason}
    end
  end
  def stop(pid), do: Process.exit(pid, :kill)
end
