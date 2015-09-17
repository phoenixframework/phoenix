defmodule Phoenix.Utils do
  @moduledoc false

  @doc """
  Returns the current timestamp in milliseconds

  ## Examples

      iex> Phoenix.Utils.now_ms()
      1442455453542

  """
  def now_ms, do: :os.timestamp() |> time_to_ms()
  defp time_to_ms({mega, sec, micro}) do
    trunc(((mega * 1000000 + sec) * 1000) + (micro / 1000))
  end
end
