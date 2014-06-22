defmodule Phoenix.UserTest.Views.Users do
  use Phoenix.UserTest.Views


  def truncate_desc(text, length), do: String.slice(text, 0, length) <> "..."
end

