defmodule Mix.Tasks.Phoenix.Gen.Channel do
  use Mix.Task

  @shortdoc "Generates a Phoenix channel"

  @moduledoc """
  Generates a Phoenix channel.

      mix phoenix.gen.channel Room rooms

  The first argument is the module name for the channel.
  The second argument is the plural used as the topic.

  The generated model will contain:

    * a channel in web/channels
    * a channel_test in test/channels

  """
  def run(args) do
    [singular, plural] = validate_args!(args)

    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]

    binding = binding ++ [plural: plural]

    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "Channel")

    Mix.Phoenix.copy_from paths(), "priv/templates/phoenix.gen.channel", "", binding, [
      {:eex, "channel.ex",       "web/channels/#{path}_channel.ex"},
      {:eex, "channel_test.exs", "test/channels/#{path}_channel_test.exs"},
    ]

    Mix.shell.info """

    Add the channel to your `web/channels/user_socket.ex` handler, for example:

        channel "#{plural}:lobby", #{binding[:module]}Channel
    """
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.channel expects just the module name and topic name:

        mix phoenix.gen.channel Room rooms
    """
  end

  defp validate_args!(args) do
    unless length(args) == 2 do
      raise_with_help
    end
    args
  end

  defp paths do
    [".", :phoenix]
  end
end
