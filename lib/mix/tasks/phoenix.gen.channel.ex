defmodule Mix.Tasks.Phoenix.Gen.Channel do
  @moduledoc """
  Generates a Phoenix channel.

      mix phoenix.gen.channel Room

  Accepts the module name for the channel

  The generated model will contain:

    * a channel in web/channels
    * a channel_test in test/channels

  """
  use Mix.Task

  @doc false
  def run(args) do
    IO.puts :stderr, "mix phoenix.gen.channel is deprecated. Use phx.gen.channel instead."

    [module] = validate_args!(args)

    binding = Mix.Phoenix.inflect(module)
    path    = binding[:path]

    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "Channel")

    Mix.Phoenix.copy_from paths(), "priv/templates/phoenix.gen.channel", binding, [
      {:eex, "channel.ex",       "web/channels/#{path}_channel.ex"},
      {:eex, "channel_test.exs", "test/channels/#{path}_channel_test.exs"},
    ]

    Mix.shell.info """

    Add the channel to your `web/channels/user_socket.ex` handler, for example:

        channel "#{binding[:singular]}:lobby", #{binding[:module]}Channel
    """
  end

  @doc false
  @spec raise_with_help() :: no_return()
  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.channel expects just the module name:

        mix phoenix.gen.channel Room
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
