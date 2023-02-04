defmodule Phoenix do
  @moduledoc """
  This is the documentation for the Phoenix project.

  To get started, see our [overview guides](overview.html).

  ## Dependencies

  By default, Phoenix applications depend on several packages with
  different purposes. The main packages are:

    * [Ecto](https://hexdocs.pm/ecto) - a language integrated query and
      database wrapper

    * [Phoenix](https://hexdocs.pm/phoenix) - the Phoenix web framework
      (these docs)

    * [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) - build rich,
      real-time user experiences with server-rendered HTML. The LiveView
      project also defines `Phoenix.Component` and
      [the HEEx template engine](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#sigil_H/2),
      used for rendering HTML content in both regular and real-time applications

    * [Plug](https://hexdocs.pm/plug) - specification and conveniences for
      building composable modules web applications. This is the package
      responsible for the connection abstraction and the regular request-
      response life-cycle

  You will also work with the following:

    * [ExUnit](https://hexdocs.pm/ex_unit) - Elixir's built-in test framework

    * [Gettext](https://hexdocs.pm/gettext) - internationalization and
      localization through [`gettext`](https://www.gnu.org/software/gettext/)

    * [Swoosh](https://hexdocs.pm/swoosh) - a library for composing,
      delivering and testing emails, also used by `mix phx.gen.auth`

  When peaking under the covers, you will find those libraries play
  an important role in Phoenix applications:

    * [Phoenix HTML](https://hexdocs.pm/phoenix_html) - building blocks
      for working with HTML and Forms safely

    * [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub) - a distributed
      pub/sub system with presence support

  When it comes to instrumentation and monitoring, check out:

    * [Phoenix LiveDashboard](https://hexdocs.pm/phoenix_live_dashboard) -
      real-time performance monitoring and debugging tools for Phoenix
      developers

    * [Telemetry Metrics](https://hexdocs.pm/telemetry_metrics) - common
      interface for defining metrics based on Telemetry events

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

  @doc """
  Returns the configured JSON encoding library for Phoenix.

  To customize the JSON library, including the following
  in your `config/config.exs`:

      config :phoenix, :json_library, AlternativeJsonLibrary

  """
  def json_library do
    Application.get_env(:phoenix, :json_library, Jason)
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

    if configured_lib && not Code.ensure_loaded?(configured_lib) do
      IO.warn """
      found #{inspect(configured_lib)} in your application configuration
      for Phoenix JSON encoding, but module #{inspect(configured_lib)} is not available.
      Ensure #{inspect(configured_lib)} is listed as a dependency in mix.exs.
      """
    end
  end
end
