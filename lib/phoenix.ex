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

  There are also optional packages depending on your configuration:

    * [Phoenix PubSub Redis](http://hexdocs.pm/phoenix_live_reload) - use
      Redis to power Phoenix PubSub system

  """
  use Application

  @doc false
  def start(_type, _args) do
    # Warm up caches
    _ = Phoenix.Template.engines
    _ = Phoenix.Template.format_encoder("index.html")

    # Start the supervision tree
    Phoenix.Supervisor.start_link
  end
end
