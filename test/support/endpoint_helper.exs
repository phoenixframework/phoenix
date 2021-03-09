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
    {:ok, socket} = :gen_tcp.listen(0, [])
    socket
  end

  defp get_port_number_and_close(socket) do
    {:ok, port_number} = :inet.port(socket)
    :gen_tcp.close(socket)
    port_number
  end
end
