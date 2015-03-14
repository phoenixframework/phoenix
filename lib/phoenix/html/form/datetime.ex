defmodule Phoenix.HTML.Form.Datetime do
  @moduledoc ~S"""
    Helpers for forms with datetime selection.
  """

  defp map seq do
    Enum.into(seq, [], fn i ->
        i = Integer.to_string(i)
        {i, String.rjust(i, 2, ?0)}
      end)
  end

  def days do map(1..31) end
  def hours do map(0..23) end
  def minsec do map(0..59) end
  def months do
    [
      { "1",  "January" },
      { "2",  "February" },
      { "3",  "March" },
      { "4",  "April" },
      { "5",  "May" },
      { "6",  "June" },
      { "7",  "July" },
      { "8",  "August" },
      { "9",  "September" },
      { "10", "October" },
      { "11", "November" },
      { "12", "December" }
    ]
  end
end

