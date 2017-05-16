defmodule Mix.Tasks.Phoenix.Gen.Secret do
  @moduledoc """
  Generates a secret and prints it to the terminal.

      mix phoenix.gen.secret [length]

  By default, mix phoenix.gen.secret generates a key 64 characters long.

  The minimum value for `length` is 32.
  """
  use Mix.Task

  @doc false
  def run(args) do
    IO.puts :stderr, "mix phoenix.gen.secret is deprecated. Use phx.gen.secret instead."
    Mix.Tasks.Phx.Gen.Secret.run(args)
  end
end
