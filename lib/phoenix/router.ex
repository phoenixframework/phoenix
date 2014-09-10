defmodule Phoenix.Router do
  @moduledoc """
  Defines the Phoenix router.

  A router is the heart of a Phoenix application. It defines
  the main stack your web application will use to handle requests
  as well as the valid routes and endpoints.
  """

  alias Phoenix.Plugs
  alias Phoenix.Router.Adapter
  alias Phoenix.Plugs.Parsers
  alias Phoenix.Config
  alias Phoenix.Project

  defmacro __using__(plug_adapter_options \\ []) do
    quote do
      use Phoenix.Router.Mapper

      # TODO: This should not be adapter specific.
      use Phoenix.Adapters.Cowboy

      @before_compile unquote(__MODULE__)
      use Plug.Builder

      # TODO: Test and document all of those configurations

      if Config.router(__MODULE__, [:static_assets]) do
        mount = Config.router(__MODULE__, [:static_assets_mount])
        plug Plug.Static, at: mount, from: Project.app
      end

      plug Plug.Logger

      if Config.router(__MODULE__, [:parsers]) do
        plug Plug.Parsers, parsers: [:urlencoded, :multipart, Parsers.JSON], accept: ["*/*"]
      end

      if Config.get([:code_reloader, :enabled]) do
        plug Plugs.CodeReloader
      end

      if Config.router(__MODULE__, [:cookies]) do
        key    = Config.router!(__MODULE__, [:session_key])
        secret = Config.router!(__MODULE__, [:session_secret])

        plug Plug.Session, store: :cookie, key: key, secret: secret
        plug Plugs.SessionFetcher
      end

      plug Plug.MethodOverride

      @options unquote(plug_adapter_options)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # TODO: Test this is actually added at the end.
      unless Plugs.plugged?(@plugs, :dispatch) do
        plug :dispatch
      end

      def dispatch(conn, []) do
        Phoenix.Router.Adapter.dispatch(conn, __MODULE__)
      end

      def start do
        options = Adapter.merge(@options, @dispatch_options, __MODULE__, Cowboy)
        Adapter.start(__MODULE__, options)
      end

      def stop do
        options = Adapter.merge(@options, @dispatch_options, __MODULE__, Cowboy)
        Adapter.stop(__MODULE__, options)
      end
    end
  end
end
