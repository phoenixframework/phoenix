defmodule Phoenix do
  @moduledoc """
  This is the documentation for the Phoenix project.

  By default, Phoenix applications depend on the following packages:

    * [Ecto](https://hexdocs.pm/ecto) - a language integrated query and
      database wrapper

    * [Phoenix](https://hexdocs.pm/phoenix) - the Phoenix web framework
      (these docs)

    * [Phoenix.js](js) - Phoenix Channels JavaScript client

    * [Phoenix Pubsub](https://hexdocs.pm/phoenix_pubsub) - a distributed
      pubsub system with presence support

    * [Phoenix HTML](https://hexdocs.pm/phoenix_html) - conveniences for
      working with HTML in Phoenix

    * [Plug](https://hexdocs.pm/plug) - a specification and conveniences
      for composable modules in between web applications

    * [Gettext](https://hexdocs.pm/gettext) - Internationalization and
      localization through gettext

  There are also optional packages depending on your configuration:

    * [Phoenix PubSub Redis](https://hexdocs.pm/phoenix_pubsub_redis) - use
      Redis to power Phoenix PubSub system

  """
  use Application

  @doc false
  def start(_type, _args) do
    # Warm up caches
    _ = Phoenix.Template.engines()
    _ = Phoenix.Template.format_encoder("index.html")
    warn_on_missing_format_encoders()

    # Configure proper system flags from Phoenix only
    if stacktrace_depth = Application.get_env(:phoenix, :stacktrace_depth) do
      :erlang.system_flag(:backtrace_depth, stacktrace_depth)
    end

    # Start the supervision tree
    import Supervisor.Spec

    children = [
      # Code reloading must be serial across all Phoenix apps
      worker(Phoenix.CodeReloader.Server, [])
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Phoenix.Supervisor)
  end

  @doc false
  # TODO remove Poison default in 2.0
  def json do
    :phoenix
    |> Application.fetch_env!(:format_encoders)
    |> Keyword.get(:json, Poison)
  end

  defp warn_on_missing_format_encoders do
    for {format, mod} <- Application.fetch_env!(:phoenix, :format_encoders) do
      Code.ensure_loaded?(mod) || IO.write :sterr, """
      failed to load #{inspect(mod)} for Phoenix :#{format} encoder
      (module #{inspect(mod)} is not available)

      Ensure #{inspect(mod)} is loaded from your deps in mix.exs, or
      configure an existing encoder in your mix config using:

          config :phoenix, :format_encoders, #{format}: MyEncoder
      """
    end
  end
end
