defmodule Phoenix do
  @moduledoc """
  This is the documentation for the Phoenix project.

  By default, Phoenix applications depend on the following packages:

    * [Ecto](https://hexdocs.pm/ecto) - a language integrated query and
      database wrapper

    * [EEx](https://hexdocs.pm/eex) - Elixir's built-in templating language

    * [ExUnit](https://hexdocs.pm/ex_unit) - Elixir's built-in test framework

    * [Phoenix](https://hexdocs.pm/phoenix) - the Phoenix web framework
      (these docs)

    * [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub) - a distributed
      pub/sub system with presence support

    * [Phoenix HTML](https://hexdocs.pm/phoenix_html) - conveniences for
      working with HTML in Phoenix

    * [Plug](https://hexdocs.pm/plug) - a specification and conveniences
      for composable modules in between web applications

    * [Gettext](https://hexdocs.pm/gettext) - Internationalization and
      localization through [`gettext`](https://www.gnu.org/software/gettext/)

  To get started, see our [overview guides](overview.html).
  """
  use Application

  @doc false
  def start(_type, _args) do
    # Warm up caches
    _ = Phoenix.Template.engines()
    _ = Phoenix.Template.format_encoder("index.html")
    warn_on_missing_json_library()

    # Configure proper system flags from Phoenix only
    if stacktrace_depth = Application.get_env(:phoenix, :stacktrace_depth) do
      :erlang.system_flag(:backtrace_depth, stacktrace_depth)
    end

    if Application.fetch_env!(:phoenix, :logger) do
      Phoenix.Logger.install()
    end

    children = [
      # Code reloading must be serial across all Phoenix apps
      Phoenix.CodeReloader.Server,
      {DynamicSupervisor, name: Phoenix.Transports.LongPoll.Supervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Phoenix.Supervisor)
  end

  # TODO v2: swap Poison default with Jason
  # From there we can ditch explicit config for new projects
  @doc """
  Returns the configured JSON encoding library for Phoenix.

  To customize the JSON library, including the following
  in your `config/config.exs`:

      config :phoenix, :json_library, Jason

  """
  def json_library do
    Application.get_env(:phoenix, :json_library, Poison)
  end

  @doc """
  Returns the `:plug_init_mode` that controls when plugs are
  initialized.

  We recommend to set it to `:runtime` in development for
  compilation time improvements. It must be `:compile` in
  production (the default).

  This option is passed as the `:init_mode` to `Plug.Builder.compile/3`.
  """
  def plug_init_mode do
    Application.get_env(:phoenix, :plug_init_mode, :compile)
  end

  defp warn_on_missing_json_library do
    configured_lib = Application.get_env(:phoenix, :json_library)

    cond do
      configured_lib && Code.ensure_loaded?(configured_lib) ->
        true

      configured_lib && not Code.ensure_loaded?(configured_lib) ->
        IO.warn """
        found #{inspect(configured_lib)} in your application configuration
        for Phoenix JSON encoding, but module #{inspect(configured_lib)} is not available.
        Ensure #{inspect(configured_lib)} is listed as a dependency in mix.exs.
        """

      true ->
        IO.warn """
        Phoenix now requires you to explicitly list which engine to use
        for Phoenix JSON encoding. We recommend everyone to upgrade to
        Jason by setting in your config/config.exs:

            config :phoenix, :json_library, Jason

        And then adding {:jason, "~> 1.0"} as a dependency.

        If instead you would rather continue using Poison, then add to
        your config/config.exs:

            config :phoenix, :json_library, Poison
        """
    end
  end
end
