defmodule Phoenix do
  @moduledoc """
  This is documentation for the Phoenix project.

  By default, Phoenix applications depend on other packages besides
  Phoenix itself. Below we provide a short explanation with links to
  their documentation for each of those projects:

    * [Ecto](http://hexdocs.pm/ecto) - a language integrated query and
      database wrapper

    * [Phoenix](http://hexdocs.pm/phoenix) - the Phoenix web framework
      (these docs)

    * [Phoenix HTML](http://hexdocs.pm/phoenix_html) - conveniences for
      working with HTML in Phoenix

    * [Plug](http://hexdocs.pm/plug) - a specification and conveniences
      for composable modules in between web applications

    * [Gettext](http://hexdocs.pm/gettext) - Internationalization and
      localization through gettext

  There are also optional packages depending on your configuration:

    * [Phoenix PubSub Redis](http://hexdocs.pm/phoenix_pubsub_redis) - use
      Redis to power Phoenix PubSub system

  """
  use Application

  @doc false
  def start(_type, _args) do
    # Warm up caches
    _ = Phoenix.Template.engines
    _ = Phoenix.Template.format_encoder("index.html")

    # Configure proper system flags from Phoenix only
    if stacktrace_depth = Application.get_env(:phoenix, :stacktrace_depth) do
      :erlang.system_flag(:backtrace_depth, stacktrace_depth)
    end

    # Start the supervision tree
    Phoenix.Supervisor.start_link
  end
end
