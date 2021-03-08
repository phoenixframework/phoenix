defmodule Phoenix.Integration.EndpointHelper do
  @moduledoc """
  Utility functions for integration testing endpoints.
  """

  @doc """
  Finds `n` unused network port numbers.
  """
  def get_unused_port_numbers(n) when is_integer(n) and n > 1 do
    (1..n)
    # Open up `n` sockets at the same time, so we don't get
    # duplicate port numbers
    |> Enum.map(&listen_on_os_assigned_port/1)
    |> Enum.map(&get_port_number_and_close/1)
  end

  defp listen_on_os_assigned_port(_) do
    {:ok, socket} = :gen_tcp.listen(0, so_reuseport())
    socket
  end

  defp get_port_number_and_close(socket) do
    {:ok, port_number} = :inet.port(socket)
    :gen_tcp.close(socket)
    port_number
  end

  @doc """
  Socket option to allow a port to be reused.

  When provided as a socket option, this allows for a port to be bound to by
  multiple processes and prevents `:eaddrinuse` errors. This is useful in
  Phoenix's integration tests because in order to get an unused port number from
  the OS in `get_unused_port_numbers/1` we have to open and close a socket,
  which temporarily makes the port number unavailable to other processes while
  the OS is shutting it down (the shutdown process continues even after
  `:gen_tcp.close/1` returns). Trying to reuse the port number before this
  shutdown process is complete causes `:eaddrinuse` errors, unless the original
  socket and the new socket that is being opened are opened with the
  `so_reuseport` option.
  """
  def so_reuseport do
    case :os.type() do
      {:unix, :linux} -> [{:raw, 1, 15, <<1::32-native>>}]
      {:unix, :darwin} -> [{:raw, 65_535, 512, <<1::32-native>>}]
      _ -> []
    end
  end
end
