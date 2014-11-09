defmodule Phoenix.Template.ExsEngine do
  @moduledoc """
  The Phoenix engine that handles the `.exs` extension.
  """

  @behaviour Phoenix.Template.Engine

  def compile(path, _name) do
    path
    |> File.read!
    |> Code.string_to_quoted!(file: path)
  end
end
