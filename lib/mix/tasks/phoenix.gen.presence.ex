defmodule Mix.Tasks.Phoenix.Gen.Presence do
  use Mix.Task

  @shortdoc "Generates a Presence tracker"

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
  def run([]) do
    run(["Presence"])
  end
  def run([alias_name]) do
    binding = Mix.Phoenix.inflect(alias_name) ++ [otp_app: Mix.Phoenix.otp_app()]
    files = [
      {:eex, "presence.ex", "web/channels/#{binding[:path]}.ex"},
    ]
    Mix.Phoenix.copy_from paths(), "priv/templates/phoenix.gen.presence", "", binding, files

    Mix.shell.info """

    *Required* post-install setup:


    First, add configuration for your #{binding[:module]} tracker,
    in config/config.exs:

        config :my_app, #{binding[:module]},
          pubsub_server: #{inspect Module.concat(binding[:base], PubSub)}


    Next, add your new module to your supervision tree,
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
