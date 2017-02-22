defmodule Mix.Tasks.Phx.Gen.Channel do
  @shortdoc "Generates a Phoenix channel"

  @moduledoc """
  Generates a Phoenix channel.

      mix phx.gen.channel Room

  Accepts the module name for the channel

  The generated files will contain:

  For a regular application:

    * a channel in lib/my_app/web/channels
    * a channel_test in test/web/channels

  For an umbrella application:

    * a channel in lib/my_app/channels
    * a channel_test in test/channels
  """
  use Mix.Task

  def run(args) do
    [channel_name] = validate_args!(args)

    web_prefix = Mix.Phoenix.web_prefix()
    test_prefix = Mix.Phoenix.test_prefix()
    binding = Mix.Phoenix.inflect(channel_name)
    binding = Keyword.put(binding, :module, "#{binding[:web_module]}.#{binding[:scoped]}")

    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "Channel")

    Mix.Phoenix.copy_from paths(), "priv/templates/phx.gen.channel", "", binding, [
      {:eex, "channel.ex",       Path.join(web_prefix, "channels/#{binding[:path]}_channel.ex")},
      {:eex, "channel_test.exs", Path.join(test_prefix, "channels/#{binding[:path]}_channel_test.exs")},
    ]

    Mix.shell.info """

    Add the channel to your `#{Mix.Phoenix.web_path("channels/user_socket.ex")}` handler, for example:

        channel "#{binding[:singular]}:lobby", #{binding[:module]}Channel
    """
  end

  @spec raise_with_help() :: no_return()
  defp raise_with_help do
    Mix.raise """
    mix phx.gen.channel expects just the module name:

        mix phx.gen.channel Room
    """
  end

  defp validate_args!(args) do
    unless length(args) == 1 do
      raise_with_help()
    end
    args
  end

  defp paths do
    [".", :phoenix]
  end
end
