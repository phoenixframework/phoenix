defmodule Mix.Tasks.Phoenix.New do
  use Mix.Task
  import Mix.Generator

  @phoenix Path.expand("../../../..", __DIR__)
  @version Mix.Project.config[:version]
  @shortdoc "Creates a new Phoenix v#{@version} application"

  # File mappings

  @new [
    {:eex,  "new/config/config.exs",                         "config/config.exs"},
    {:eex,  "new/config/dev.exs",                            "config/dev.exs"},
    {:eex,  "new/config/prod.exs",                           "config/prod.exs"},
    {:eex,  "new/config/prod.secret.exs",                    "config/prod.secret.exs"},
    {:eex,  "new/config/test.exs",                           "config/test.exs"},
    {:eex,  "new/lib/app_name.ex",                           "lib/app_name.ex"},
    {:eex,  "new/lib/app_name/endpoint.ex",                  "lib/app_name/endpoint.ex"},
    {:keep, "new/test/channels",                             "test/channels"},
    {:keep, "new/test/controllers",                          "test/controllers"},
    {:eex,  "new/test/views/error_view_test.exs",            "test/views/error_view_test.exs"},
    {:eex,  "new/test/support/conn_case.ex",                 "test/support/conn_case.ex"},
    {:eex,  "new/test/support/channel_case.ex",              "test/support/channel_case.ex"},
    {:eex,  "new/test/test_helper.exs",                      "test/test_helper.exs"},
    {:eex,  "new/web/channels/user_socket.ex",               "web/channels/user_socket.ex"},
    {:keep, "new/web/controllers",                           "web/controllers"},
    {:keep, "new/web/models",                                "web/models"},
    {:eex,  "new/web/router.ex",                             "web/router.ex"},
    {:keep, "new/web/static/vendor",                         "web/static/vendor"},
    {:eex,  "new/web/views/error_view.ex",                   "web/views/error_view.ex"},
    {:eex,  "new/web/web.ex",                                "web/web.ex"},
    {:eex,  "new/mix.exs",                                   "mix.exs"},
    {:eex,  "new/README.md",                                 "README.md"},
    {:eex,  "new/web/gettext.ex",                            "web/gettext.ex"},
    {:eex,  "new/priv/gettext/errors.pot",                   "priv/gettext/errors.pot"},
    {:eex,  "new/priv/gettext/en/LC_MESSAGES/errors.po",     "priv/gettext/en/LC_MESSAGES/errors.po"},
    {:eex,  "new/web/views/error_helpers.ex",                "web/views/error_helpers.ex"},
  ]

  @ecto [
    {:eex,  "ecto/repo.ex",              "lib/app_name/repo.ex"},
    {:keep, "ecto/test/models",          "test/models"},
    {:eex,  "ecto/model_case.ex",        "test/support/model_case.ex"},
    {:keep, "ecto/priv/repo/migrations", "priv/repo/migrations"},
    {:eex,  "ecto/seeds.exs",            "priv/repo/seeds.exs"}
  ]

  @brunch [
    {:text, "static/brunch/gitignore",       ".gitignore"},
    {:eex,  "static/brunch/brunch-config.js", "brunch-config.js"},
    {:eex,  "static/brunch/package.json",     "package.json"},
    {:text, "static/app.css",                 "web/static/css/app.css"},
    {:text, "static/phoenix.css",             "web/static/css/phoenix.css"},
    {:eex,  "static/brunch/app.js",           "web/static/js/app.js"},
    {:eex,  "static/brunch/socket.js",        "web/static/js/socket.js"},
    {:text, "static/robots.txt",              "web/static/assets/robots.txt"},
  ]

  @html [
    {:eex,  "new/test/controllers/page_controller_test.exs", "test/controllers/page_controller_test.exs"},
    {:eex,  "new/test/views/layout_view_test.exs",           "test/views/layout_view_test.exs"},
    {:eex,  "new/test/views/page_view_test.exs",             "test/views/page_view_test.exs"},
    {:eex,  "new/web/controllers/page_controller.ex",        "web/controllers/page_controller.ex"},
    {:eex,  "new/web/templates/layout/app.html.eex",         "web/templates/layout/app.html.eex"},
    {:eex,  "new/web/templates/page/index.html.eex",         "web/templates/page/index.html.eex"},
    {:eex,  "new/web/views/layout_view.ex",                  "web/views/layout_view.ex"},
    {:eex,  "new/web/views/page_view.ex",                    "web/views/page_view.ex"},
  ]

  @static [
    {:text,   "static/bare/gitignore", ".gitignore"},
    {:text,   "static/app.css",         "priv/static/css/app.css"},
    {:append, "static/phoenix.css",     "priv/static/css/app.css"},
    {:text,   "static/bare/app.js",     "priv/static/js/app.js"},
    {:text,   "static/robots.txt",      "priv/static/robots.txt"},
  ]

  @bare [
    {:text,   "static/bare/gitignore", ".gitignore"},
  ]

  # Embed all defined templates
  root = Path.expand("../../../templates", __DIR__)

  for {format, source, _} <- @new ++ @ecto ++ @brunch ++ @html ++ @static ++ @bare do
    unless format == :keep do
      @external_resource Path.join(root, source)
      def render(unquote(source)), do: unquote(File.read!(Path.join(root, source)))
    end
  end

  # Embed missing files from Phoenix static.
  embed_text :phoenix_js, from_file: Path.expand("../../../../priv/static/phoenix.js", __DIR__)
  embed_text :phoenix_png, from_file: Path.expand("../../../../priv/static/phoenix.png", __DIR__)
  embed_text :phoenix_favicon, from_file: Path.expand("../../../../priv/static/favicon.ico", __DIR__)

  @moduledoc """
  Creates a new Phoenix project.

  It expects the path of the project as argument.

      mix phoenix.new PATH [--module MODULE] [--app APP]

  A project at the given PATH will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.

  ## Options

    * `--app` - the name of the OTP application

    * `--module` - the name of the base module in
      the generated skeleton

    * `--database` - specify the database adapter for ecto.
      Values can be `postgres` or `mysql`. Defaults to `postgres`.

    * `--no-brunch` - do not generate brunch files
      for static asset building. When choosing this
      option, you will need to manually handle
      JavaScript dependencies if building HTML apps

    * `--no-ecto` - do not generate ecto files for
      the model layer

    * `--no-html` - do not generate HTML views.

    * `--binary-id` - use `binary_id` as primary key type
      in ecto models

  ## Examples

      mix phoenix.new hello_world

  Is equivalent to:

      mix phoenix.new hello_world --module HelloWorld

  Without brunch:

      mix phoenix.new ~/Workspace/hello_world --no-brunch

  """
  @switches [dev: :boolean, brunch: :boolean, ecto: :boolean,
             app: :string, module: :string, database: :string,
             binary_id: :boolean, html: :boolean]

  def run([version]) when version in ~w(-v --version) do
    Mix.shell.info "Phoenix v#{@version}"
  end

  def run(argv) do
    unless Version.match? System.version, "~> 1.2" do
      Mix.raise "Phoenix v#{@version} requires at least Elixir v1.2.\n " <>
                "You have #{System.version}. Please update accordingly"
    end

    {opts, argv} =
      case OptionParser.parse(argv, strict: @switches) do
        {opts, argv, []} ->
          {opts, argv}
        {_opts, _argv, [switch | _]} ->
          Mix.raise "Invalid option: " <> switch_to_string(switch)
      end

    case argv do
      [] ->
        Mix.Tasks.Help.run ["phoenix.new"]
      [path|_] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !!opts[:app])
        check_directory_existence!(app)
        mod = opts[:module] || Macro.camelize(app)
        check_module_name_validity!(mod)
        check_module_name_availability!(mod)

        run(app, mod, path, opts)
    end
  end

  def run(app, mod, path, opts) do
    db = Keyword.get(opts, :database, "postgres")
    ecto = Keyword.get(opts, :ecto, true)
    html = Keyword.get(opts, :html, true)
    brunch = Keyword.get(opts, :brunch, true)
    phoenix_path = phoenix_path(path, Keyword.get(opts, :dev, false))

    # We lowercase the database name because according to the
    # SQL spec, they are case insensitive unless quoted, which
    # means creating a database like FoO is the same as foo in
    # some storages.
    {adapter_app, adapter_module, adapter_config} = get_ecto_adapter(db, String.downcase(app), mod)
    pubsub_server = get_pubsub_server(mod)
    in_umbrella? = in_umbrella?(path)
    brunch_deps_prefix = if in_umbrella?, do: "../../", else: ""

    adapter_config =
      case Keyword.fetch(opts, :binary_id) do
        {:ok, value} -> Keyword.put_new(adapter_config, :binary_id, value)
        :error -> adapter_config
      end


    generator_config =
      case get_generator_config(adapter_config) do
        []               -> nil
        generator_config ->
          """

          # Configure phoenix generators
          config :phoenix, :generators#{kw_to_config(generator_config)}
          """
      end

    binding = [app_name: app,
               app_module: mod,
               phoenix_dep: phoenix_dep(phoenix_path),
               phoenix_path: phoenix_path,
               phoenix_static_path: phoenix_static_path(phoenix_path),
               pubsub_server: pubsub_server,
               secret_key_base: random_string(64),
               prod_secret_key_base: random_string(64),
               signing_salt: random_string(8),
               in_umbrella: in_umbrella?,
               brunch_deps_prefix: brunch_deps_prefix,
               brunch: brunch,
               ecto: ecto,
               html: html,
               adapter_app: adapter_app,
               adapter_module: adapter_module,
               adapter_config: adapter_config,
               hex?: Code.ensure_loaded?(Hex),
               generator_config: generator_config,
               namespaced?: Macro.camelize(app) != mod]

    copy_from path, binding, @new

    # Optional contents
    copy_model  app, path, binding
    copy_static app, path, binding
    copy_html   app, path, binding

    # Parallel installs
    install? = Mix.shell.yes?("\nFetch and install dependencies?")

    File.cd!(path, fn ->
      mix?    = install_mix(install?)
      brunch? = install_brunch(install?)
      extra   = if mix?, do: [], else: ["$ mix deps.get"]

      print_mix_info(path, extra)

      if binding[:ecto] do
        print_ecto_info()
      end

      if not brunch? do
        print_brunch_info()
      end
    end)
  end

  defp switch_to_string({name, nil}), do: name
  defp switch_to_string({name, val}), do: name <> "=" <> val

  defp copy_model(_app, path, binding) do
    if binding[:ecto] do
      copy_from path, binding, @ecto

      adapter_config = binding[:adapter_config]

      append_to path, "config/dev.exs", """

      # Configure your database
      config :#{binding[:app_name]}, #{binding[:app_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:dev]},
        pool_size: 10
      """

      append_to path, "config/test.exs", """

      # Configure your database
      config :#{binding[:app_name]}, #{binding[:app_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:test]}
      """

      append_to path, "config/prod.secret.exs", """

      # Configure your database
      config :#{binding[:app_name]}, #{binding[:app_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:prod]},
        pool_size: 15
      """
    end
  end

  defp get_generator_config(adapter_config) do
    adapter_config
    |> Keyword.take([:binary_id, :migration, :sample_binary_id])
    |> Enum.filter(fn {_, value} -> not is_nil(value) end)
  end

  defp copy_static(_app, path, binding) do
    case {binding[:brunch], binding[:html]} do
    {true, _} ->
      copy_from path, binding, @brunch
      create_file Path.join(path, "web/static/assets/images/phoenix.png"), phoenix_png_text()
      create_file Path.join(path, "web/static/assets/favicon.ico"), phoenix_favicon_text()
    {false, true} ->
      copy_from path, binding, @static
      create_file Path.join(path, "priv/static/js/phoenix.js"), phoenix_js_text()
      create_file Path.join(path, "priv/static/images/phoenix.png"), phoenix_png_text()
      create_file Path.join(path, "priv/static/favicon.ico"), phoenix_favicon_text()
    {false, false} ->
      copy_from path, binding, @bare
    end
  end

  defp copy_html(_app, path, binding) do
    if binding[:html] do
      copy_from path, binding, @html
    end
  end

  defp install_brunch(install?) do
    maybe_cmd "npm install && node node_modules/brunch/bin/brunch build",
              File.exists?("brunch-config.js"), install? && System.find_executable("npm")
  end

  defp install_mix(install?) do
    maybe_cmd "mix deps.get", true, install? && Code.ensure_loaded?(Hex)
  end

  defp print_brunch_info do
    Mix.shell.info """

    Phoenix uses an optional assets build tool called brunch.io
    that requires node.js and npm. Installation instructions for
    node.js, which includes npm, can be found at http://nodejs.org.

    After npm is installed, install your brunch dependencies by
    running inside your app:

        $ npm install

    If you don't want brunch.io, you can re-run this generator
    with the --no-brunch option.
    """
    nil
  end

  defp print_ecto_info do
    Mix.shell.info """
    Before moving on, configure your database in config/dev.exs and run:

        $ mix ecto.create
    """
  end

  defp print_mix_info(path, extra) do
    steps = ["$ cd #{path}"] ++ extra ++ ["$ mix phoenix.server"]

    Mix.shell.info """

    We are all set! Run your Phoenix application:

        #{Enum.join(steps, "\n    ")}

    You can also run your app inside IEx (Interactive Elixir) as:

        $ iex -S mix phoenix.server
    """
  end

  ## Helpers

  defp maybe_cmd(cmd, should_run?, can_run?) do
    cond do
      should_run? && can_run? ->
        cmd(cmd)
        true
      should_run? ->
        false
      true ->
        true
    end
  end

  defp cmd(cmd) do
    Mix.shell.info [:green, "* running ", :reset, cmd]
    case Mix.shell.cmd(cmd, [quiet: true]) do
      0 ->
        true
      _ ->
        Mix.shell.error [:red, "* error ", :reset, "command failed to execute, " <>
          "please run the following command again after installation: \"#{cmd}\""]
        false
    end
  end

  defp check_application_name!(name, from_app_flag) do
    unless name =~ ~r/^[a-z][\w_]*$/ do
      extra =
        if !from_app_flag do
          ". The application name is inferred from the path, if you'd like to " <>
          "explicitly name the application then use the `--app APP` option."
        else
          ""
        end

      Mix.raise "Application name must start with a letter and have only lowercase " <>
                "letters, numbers and underscore, got: #{inspect name}" <> extra
    end
  end

  defp check_module_name_validity!(name) do
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect name}"
    end
  end

  defp check_module_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  defp check_directory_existence!(name) do
    if File.dir?(name) and not Mix.shell.yes?("The directory #{name} already exists. Are you sure you want to continue?") do
      Mix.raise "Please select another directory for installation."
    end
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
     test_setup_all: "Ecto.Adapters.SQL.Sandbox.mode(#{module}.Repo, :manual)",
     test_setup: ":ok = Ecto.Adapters.SQL.Sandbox.checkout(#{module}.Repo)",
     test_async: "Ecto.Adapters.SQL.Sandbox.mode(#{module}.Repo, {:shared, self()})"]
  end

  defp kw_to_config(kw) do
    Enum.map(kw, fn {k, v} ->
      ",\n  #{k}: #{inspect v}"
    end)
  end

  defp get_pubsub_server(module) do
    module
    |> String.split(".")
    |> hd
    |> Module.concat(PubSub)
  end

  defp in_umbrella?(app_path) do
    try do
      umbrella = Path.expand(Path.join [app_path, "..", ".."])
      File.exists?(Path.join(umbrella, "mix.exs")) &&
        Mix.Project.in_project(:umbrella_check, umbrella, fn _ ->
          path = Mix.Project.config[:apps_path]
          path && Path.expand(path) == Path.join(umbrella, "apps")
        end)
    catch
      _, _ -> false
    end
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
  end

  defp phoenix_dep("deps/phoenix"), do: ~s[{:phoenix, "~> 1.3.0"}]
  # defp phoenix_dep("deps/phoenix"), do: ~s[{:phoenix, github: "phoenixframework/phoenix", override: true}]
  defp phoenix_dep(path), do: ~s[{:phoenix, path: #{inspect path}, override: true}]

  defp phoenix_static_path("deps/phoenix"), do: "deps/phoenix"
  defp phoenix_static_path(path), do: Path.join("..", path)

  defp phoenix_path(path, true) do
    absolute = Path.expand(path)
    relative = Path.relative_to(absolute, @phoenix)

    if absolute == relative do
      Mix.raise "--dev projects must be generated inside Phoenix directory"
    end

    relative
    |> Path.split
    |> Enum.map(fn _ -> ".." end)
    |> Path.join
  end

  defp phoenix_path(_path, false) do
    "deps/phoenix"
  end

  ## Template helpers

  defp copy_from(target_dir, binding, mapping) when is_list(mapping) do
    app = Keyword.fetch!(binding, :app_name)
    for {format, source, target_path} <- mapping do
      target = Path.join(target_dir, String.replace(target_path, "app_name", app))

      case format do
        :keep ->
          File.mkdir_p!(target)
        :text ->
          create_file(target, render(source))
        :append ->
          append_to(Path.dirname(target), Path.basename(target), render(source))
        :eex  ->
          contents = EEx.eval_string(render(source), binding, file: source)
          create_file(target, contents)
      end
    end
  end

  defp append_to(path, file, contents) do
    file = Path.join(path, file)
    File.write!(file, File.read!(file) <> contents)
  end
end
