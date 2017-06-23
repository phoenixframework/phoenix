defmodule Mix.Tasks.Phoenix.Gen.Presence do
  @moduledoc """
  Generates a Presence tracker for your application.

      mix phoenix.gen.presence

      mix phoenix.gen.presence MyPresence

  The only argument is the module name of the Presence tracker,
  which defaults to Presence.

  A new file will be generated in:

    * web/channels/presence.ex

  Where `presence.ex` is the snake cased version of the module name provided.
  """
  use Mix.Task

  @doc false
  def run([]) do
    run(["Presence"])
  end
  def run([alias_name]) do
    IO.puts :stderr, "mix phoenix.gen.presence is deprecated. Use phx.gen.presence instead."
    inflections = Mix.Phoenix.inflect(alias_name)
    binding = inflections ++ [
      otp_app: Mix.Phoenix.otp_app(),
      pubsub_server: Module.concat(inflections[:base], PubSub)
    ]
    files = [
      {:eex, "presence.ex", "web/channels/#{binding[:path]}.ex"},
    ]
    Mix.Phoenix.copy_from paths(), "priv/templates/phx.gen.presence", binding, files

    Mix.shell.info """

    Add your new module to your supervision tree,
    in lib/#{binding[:otp_app]}.ex:

        children = [
          ...
          supervisor(#{binding[:module]}, []),
        ]

    You're all set! See the Phoenix.Presence docs for more details:
    http://hexdocs.pm/phoenix/Phoenix.Presence.html
    """
  end

  defp paths do
    [".", :phoenix]
  end
end
