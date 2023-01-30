defmodule Mix.Tasks.Compile.Phoenix do
  use Mix.Task
  @recursive true
  @moduledoc false

  @doc false
  def run(_args) do
    IO.warn("""
    the :phoenix compiler is no longer required in your mix.exs.

    Please find the following line in your mix.exs and remove the :phoenix entry:

        compilers: [..., :phoenix, ...] ++ Mix.compilers(),
    """)

    {:noop, []}
  end
end
