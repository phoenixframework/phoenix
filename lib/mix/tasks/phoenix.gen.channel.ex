defmodule Mix.Tasks.Phoenix.Gen.Channel do
  use Mix.Task

  @shortdoc "Generates a Phoenix channel"

  @moduledoc """
  Generates a Phoenix channel.

      mix phoenix.gen.channel Room rooms new_msg

  The first argument is the module name for the channel.
  The second argument is the plural used as the topic.
  The rest of the other arguments will be treated as events.

  """
  def run([singular, plural|events] = args) do
    if String.contains?(plural, ":"), do: raise_with_help
    Mix.Task.run "phoenix.gen.model", args

    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]

    binding = binding ++ [plural: plural, events: events]

    Mix.Phoenix.copy_from source_dir, "", binding, [
      {:eex, "channel.ex",       "web/channels/#{path}_channel.ex"},
      {:eex, "channel_test.exs", "test/channels/#{path}_channel_test.exs"},
    ]

    Mix.shell.info """

    Add the channel to the proper scope in web/router.ex:

        channel "#{plural}:*", #{binding[:scoped]}Channel
    """
  end

  def run(_) do
    raise_with_help
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.channel expects both the module name and topic name
    followed by any number of event names:

        mix phoenix.gen.channel Room rooms new_msg
    """
  end

  defp source_dir do
    Application.app_dir(:phoenix, "priv/templates/channel")
  end
end
