defmodule Mix.Tasks.Phx.Gen.Presence do
  @shortdoc "Generates a Presence tracker"

  @moduledoc """
  Generates a Presence tracker for your application.

      mix phx.gen.presence

      mix phx.gen.presence MyPresence

  The only argument is the module name of the Presence tracker,
  which defaults to Presence.

  A new file will be generated in:

    * lib/my_app/web/channels/presence.ex

  Where `presence.ex` is the snake cased version of the module name provided.
  """
  use Mix.Task

  def run([]) do
    run(["Presence"])
  end
  def run([alias_name]) do
    web_prefix = Mix.Phoenix.web_path(Mix.Phoenix.otp_app())
    inflections = Mix.Phoenix.inflect(alias_name)
    inflections = Keyword.put(inflections, :module, "#{inflections[:web_module]}.#{inflections[:scoped]}")

    binding = inflections ++ [
      otp_app: Mix.Phoenix.otp_app(),
      pubsub_server: Module.concat(inflections[:base], PubSub)
    ]
    files = [
      {:eex, "presence.ex", Path.join(web_prefix, "channels/#{binding[:path]}.ex")},
    ]
    Mix.Phoenix.copy_from paths(), "priv/templates/phx.gen.presence", "", binding, files

    Mix.shell.info """

    Add your new module to your supervision tree,
    in lib/#{Mix.Phoenix.otp_app()}/application.ex:

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
