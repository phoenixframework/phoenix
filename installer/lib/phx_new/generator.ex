defmodule Phx.New.Generator do
  @moduledoc false
  import Mix.Generator
  alias Phx.New.{Project}

  @phoenix Path.expand("../..", __DIR__)

  @callback prepare_project(Project.t) :: Project.t
  @callback generate(Project.t) :: Project.t

  defmacro __using__(_env) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      import Mix.Generator
      Module.register_attribute(__MODULE__, :templates, accumulate: true)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    root = Path.expand("../../templates", __DIR__)
    templates_ast = for {name, mappings} <- Module.get_attribute(env.module, :templates) do
      for {format, source, _, _} <- mappings, format != :keep do
        path = Path.join(root, source)
        quote do
          @external_resource unquote(path)
          def render(unquote(name), unquote(source)), do: unquote(File.read!(path))
        end
      end
    end

    quote do
      unquote(templates_ast)
      def template_files(name), do: Keyword.fetch!(@templates, name)
      # Embed missing files from Phoenix static.
      embed_text :phoenix_js, from_file: Path.expand("../../../priv/static/phoenix.js", unquote(__DIR__))
      embed_text :phoenix_png, from_file: Path.expand("../../../priv/static/phoenix.png", unquote(__DIR__))
      embed_text :phoenix_favicon, from_file: Path.expand("../../../priv/static/favicon.ico", unquote(__DIR__))
    end
  end

  defmacro template(name, mappings) do
    quote do
      @templates {unquote(name), unquote(mappings)}
    end
  end

  def copy_from(%Project{} = project, mod, name) when is_atom(name) do
    mapping = mod.template_files(name)
    for {format, source, project_location, target_path} <- mapping do
      target = Project.join_path(project, project_location, target_path)

      case format do
        :keep ->
          File.mkdir_p!(target)
        :text ->
          create_file(target, mod.render(name, source))
        :append ->
          append_to(Path.dirname(target), Path.basename(target), mod.render(name, source))
        :eex  ->
          contents = EEx.eval_string(mod.render(name, source), project.binding, file: source)
          create_file(target, contents)
      end
    end
  end

  def append_to(path, file, contents) do
    file = Path.join(path, file)
    File.write!(file, File.read!(file) <> contents)
  end

  def in_umbrella?(app_path) do
    umbrella = Path.expand(Path.join [app_path, "..", ".."])
    mix_path = Path.join(umbrella, "mix.exs")
    apps_path = Path.join(umbrella, "apps")

    File.exists?(mix_path) && File.exists?(apps_path)
  end

  def put_binding(%Project{opts: opts} = project) do
    db           = Keyword.get(opts, :database, "postgres")
    ecto         = Keyword.get(opts, :ecto, true)
    html         = Keyword.get(opts, :html, true)
    brunch       = Keyword.get(opts, :brunch, true)
    dev          = Keyword.get(opts, :dev, false)
    phoenix_path = phoenix_path(project, dev)

    # We lowercase the database name because according to the
    # SQL spec, they are case insensitive unless quoted, which
    # means creating a database like FoO is the same as foo in
    # some storages.
    {adapter_app, adapter_module, adapter_config} =
      get_ecto_adapter(db, String.downcase(project.app), project.app_mod)

    pubsub_server = get_pubsub_server(project.app_mod)

    adapter_config =
      case Keyword.fetch(opts, :binary_id) do
        {:ok, value} -> Keyword.put_new(adapter_config, :binary_id, value)
        :error -> adapter_config
      end

    binding = [
      app_name: project.app,
      app_module: inspect(project.app_mod),
      root_app_name: project.root_app,
      root_app_module: inspect(project.root_mod),
      web_app_name: project.web_app,
      endpoint_module: inspect(Module.concat(project.web_namespace, Endpoint)),
      web_namespace: inspect(project.web_namespace),
      phoenix_dep: phoenix_dep(phoenix_path),
      phoenix_path: phoenix_path,
      phoenix_brunch_path: phoenix_brunch_path(project, dev),
      phoenix_html_brunch_path: phoenix_html_brunch_path(project),
      phoenix_static_path: phoenix_static_path(phoenix_path),
      pubsub_server: pubsub_server,
      secret_key_base: random_string(64),
      prod_secret_key_base: random_string(64),
      signing_salt: random_string(8),
      in_umbrella: project.in_umbrella?,
      brunch: brunch,
      ecto: ecto,
      html: html,
      adapter_app: adapter_app,
      adapter_module: adapter_module,
      adapter_config: adapter_config,
      hex?: Code.ensure_loaded?(Hex),
      generators: generators(adapter_config),
      namespaced?: namespaced?(project)]

    %Project{project | binding: binding}
  end

  defp namespaced?(project) do
    project.in_umbrella? || Macro.camelize(project.app) != inspect(project.app_mod)
  end

  def gen_ecto_config(%Project{app_path: app_path, binding: binding}) do
    adapter_config = binding[:adapter_config]

    append_to app_path, "config/dev.exs", """

    # Configure your database
    config :#{binding[:app_name]}, #{binding[:app_module]}.Repo,
      adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:dev]},
      pool_size: 10
    """

    append_to app_path, "config/test.exs", """

    # Configure your database
    config :#{binding[:app_name]}, #{binding[:app_module]}.Repo,
      adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:test]}
    """

    append_to app_path, "config/prod.secret.exs", """

    # Configure your database
    config :#{binding[:app_name]}, #{binding[:app_module]}.Repo,
      adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:prod]},
      pool_size: 15
    """
  end

  defp get_pubsub_server(module) do
    module
    |> Module.split()
    |> hd()
    |> Module.concat(PubSub)
  end
  defp get_ecto_adapter("mysql", app, module) do
    {:mariaex, Ecto.Adapters.MySQL, db_config(app, module, "root", "")}
  end
  defp get_ecto_adapter("postgres", app, module) do
    {:postgrex, Ecto.Adapters.Postgres, db_config(app, module, "postgres", "postgres")}
  end
  defp get_ecto_adapter(db, _app, _mod) do
    Mix.raise "Unknown database #{inspect db}"
  end

  defp db_config(app, module, user, pass) do
    [dev:  [username: user, password: pass, database: "#{app}_dev", hostname: "localhost"],
     test: [username: user, password: pass, database: "#{app}_test", hostname: "localhost",
            pool: Ecto.Adapters.SQL.Sandbox],
     prod: [username: user, password: pass, database: "#{app}_prod"],
     test_setup_all: "Ecto.Adapters.SQL.Sandbox.mode(#{inspect module}.Repo, :manual)",
     test_setup: ":ok = Ecto.Adapters.SQL.Sandbox.checkout(#{inspect module}.Repo)",
     test_async: "Ecto.Adapters.SQL.Sandbox.mode(#{inspect module}.Repo, {:shared, self()})"]
  end

  defp kw_to_config(kw) do
    Enum.map(kw, fn {k, v} ->
      ",\n  #{k}: #{inspect v}"
    end)
  end

  defp generators(adapter_config) do
    adapter_config
    |> Keyword.take([:binary_id, :migration, :sample_binary_id])
    |> Enum.filter(fn {_, value} -> not is_nil(value) end)
    |> case do
      [] -> nil
      conf -> conf
    end
  end

  defp phoenix_path(%Project{} = project, true) do
    absolute = Path.expand(project.project_path)
    relative = Path.relative_to(absolute, @phoenix)

    if absolute == relative do
      Mix.raise "--dev projects must be generated inside Phoenix directory"
    end

    project
    |> phoenix_path_prefix()
    |> Path.join(relative)
    |> Path.split()
    |> Enum.map(fn _ -> ".." end)
    |> Path.join()
  end
  defp phoenix_path(%Project{}, false) do
    "deps/phoenix"
  end
  defp phoenix_path_prefix(%Project{in_umbrella?: true}), do: "../../../"
  defp phoenix_path_prefix(%Project{in_umbrella?: false}), do: ".."

  defp phoenix_brunch_path(%Project{in_umbrella?: true}, true = _dev),
    do: "../../../../../"
  defp phoenix_brunch_path(%Project{in_umbrella?: true}, false = _dev),
    do: "../../../deps/phoenix"
  defp phoenix_brunch_path(%Project{in_umbrella?: false}, true = _dev),
    do: "../../../"
  defp phoenix_brunch_path(%Project{in_umbrella?: false}, false = _dev),
    do: "../deps/phoenix"

  defp phoenix_html_brunch_path(%Project{in_umbrella?: true}),
    do: "../../../deps/phoenix_html"
  defp phoenix_html_brunch_path(%Project{in_umbrella?: false}),
    do: "../deps/phoenix_html"

  defp phoenix_dep("deps/phoenix"), do: ~s[{:phoenix, "~> 1.3.0-rc"}]
  # defp phoenix_dep("deps/phoenix"), do: ~s[{:phoenix, github: "phoenixframework/phoenix", override: true}]
  defp phoenix_dep(path), do: ~s[{:phoenix, path: #{inspect path}, override: true}]

  defp phoenix_static_path("deps/phoenix"), do: "deps/phoenix"
  defp phoenix_static_path(path), do: Path.join("..", path)

  defp random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
  end
end
