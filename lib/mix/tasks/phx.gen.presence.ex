defmodule Mix.Tasks.Phx.Gen.Presence do
  @shortdoc "Generates a Presence tracker"

  @moduledoc """
  Generates a Presence tracker.

      $ mix phx.gen.presence
      $ mix phx.gen.presence MyPresence

  The argument, which defaults to `Presence`, defines the module name of the
  Presence tracker.

  Generates a new file, `lib/my_app_web/channels/my_presence.ex`, where
  `my_presence` is the snake-cased version of the provided module name.
  """
  use Mix.Task

  @doc false
  def run([]) do
    run(["Presence"])
  end
  def run([alias_name]) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.presence must be invoked from within your *_web application root directory"
    end
    context_app = Mix.Phoenix.context_app()
    otp_app = Mix.Phoenix.otp_app()
    web_prefix = Mix.Phoenix.web_path(context_app)
    inflections = Mix.Phoenix.inflect(alias_name)
    inflections = Keyword.put(inflections, :module, "#{inflections[:web_module]}.#{inflections[:scoped]}")

    binding = inflections ++ [
      otp_app: otp_app,
      pubsub_server: Module.concat(inflections[:base], "PubSub")
    ]

    files = [
      {:eex, "presence.ex", Path.join(web_prefix, "channels/#{binding[:path]}.ex")},
    ]

    Mix.Phoenix.copy_from paths(), "priv/templates/phx.gen.presence", binding, files

    Mix.shell().info """

    Add your new module to your supervision tree,
    in lib/#{otp_app}/application.ex:

        children = [
          ...
          #{binding[:module]}
        ]

    You're all set! See the Phoenix.Presence docs for more details:
    http://hexdocs.pm/phoenix/Phoenix.Presence.html
    """
  end

  defp paths do
    [".", :phoenix]
  end
end
