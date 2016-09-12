defmodule Mix.Tasks.Phx.New do
  use Mix.Task
  import Mix.Generator

  @phoenix Path.expand("../..", __DIR__)
  @version Mix.Project.config[:version]
  @shortdoc "Creates a new Phoenix v#{@version} application using the experimental generators"

  # File mappings

  @new %{
    regular: [
      {:eex,  "phx_new/config/config.exs",                        "config/config.exs"},
      {:eex,  "phx_new/config/dev.exs",                           "config/dev.exs"},
      {:eex,  "phx_new/config/prod.exs",                          "config/prod.exs"},
      {:eex,  "phx_new/config/prod.secret.exs",                   "config/prod.secret.exs"},
      {:eex,  "phx_new/config/test.exs",                          "config/test.exs"},
      {:eex,  "phx_new/lib/app_name.ex",                          "lib/app_name.ex"},
      {:eex,  "phx_new/lib/app_name/web/endpoint.ex",             "lib/app_name/web/endpoint.ex"},
      {:keep, "phx_new/test/channels",                            "test/channels"},
      {:keep, "phx_new/test/controllers",                         "test/controllers"},
      {:eex,  "phx_new/test/views/error_view_test.exs",           "test/views/error_view_test.exs"},
      {:eex,  "phx_new/test/support/conn_case.ex",                "test/support/conn_case.ex"},
      {:eex,  "phx_new/test/support/channel_case.ex",             "test/support/channel_case.ex"},
      {:eex,  "phx_new/test/test_helper.exs",                     "test/test_helper.exs"},
      {:eex,  "phx_new/lib/app_name/web/channels/user_socket.ex", "lib/app_name/web/channels/user_socket.ex"},
      {:keep, "phx_new/lib/app_name/web/controllers",             "lib/app_name/web/controllers"},
      {:eex,  "phx_new/lib/app_name/web/router.ex",               "lib/app_name/web/router.ex"},
      {:eex,  "phx_new/lib/app_name/web/views/error_view.ex",     "lib/app_name/web/views/error_view.ex"},
      {:eex,  "phx_new/lib/app_name/web.ex",                      "lib/app_name/web.ex"},
      {:eex,  "phx_new/mix.exs",                                  "mix.exs"},
      {:eex,  "phx_new/README.md",                                "README.md"},
      {:eex,  "phx_new/lib/app_name/gettext.ex",                  "lib/app_name/web/gettext.ex"},
      {:eex,  "phx_new/priv/gettext/errors.pot",                  "priv/gettext/errors.pot"},
      {:eex,  "phx_new/priv/gettext/en/LC_MESSAGES/errors.po",    "priv/gettext/en/LC_MESSAGES/errors.po"},
      {:eex,  "phx_new/lib/app_name/web/views/error_helpers.ex",  "lib/app_name/web/views/error_helpers.ex"},
    ],
    umbrella: [
      {:eex,  "phx_umbrella/config/config.exs",                     "config/config.exs"},
      {:eex,  "phx_umbrella/mix.exs",                               "mix.exs"},
      {:eex,  "phx_umbrella/README.md",                             "README.md"},
      {:eex,  "phx_umbrella/apps/app_name/config/config.exs",       "apps/app_name/config/config.exs"},
      {:eex,  "phx_umbrella/apps/app_name/config/dev.exs",          "apps/app_name/config/dev.exs"},
      {:eex,  "phx_umbrella/apps/app_name/config/prod.exs",         "apps/app_name/config/prod.exs"},
      {:eex,  "phx_umbrella/apps/app_name/config/prod.secret.exs",  "apps/app_name/config/prod.secret.exs"},
      {:eex,  "phx_umbrella/apps/app_name/config/test.exs",         "apps/app_name/config/test.exs"},
      {:eex,  "phx_umbrella/apps/app_name/lib/app_name.ex",         "apps/app_name/lib/app_name.ex"},
      {:eex,  "phx_umbrella/apps/app_name/test/test_helper.exs",    "apps/app_name/test/test_helper.exs"},
      {:eex,  "phx_umbrella/apps/app_name/README.md",               "apps/app_name/README.md"},
      {:eex,  "phx_umbrella/apps/app_name/mix.exs",                 "apps/app_name/mix.exs"},
      {:eex,  "phx_umbrella/apps/app_name_web/config/config.exs",       "apps/app_name_web/config/config.exs"},
      {:eex,  "phx_umbrella/apps/app_name_web/config/dev.exs",          "apps/app_name_web/config/dev.exs"},
      {:eex,  "phx_umbrella/apps/app_name_web/config/prod.exs",         "apps/app_name_web/config/prod.exs"},
      {:eex,  "phx_umbrella/apps/app_name_web/config/prod.secret.exs",  "apps/app_name_web/config/prod.secret.exs"},
      {:eex,  "phx_umbrella/apps/app_name_web/config/test.exs",         "apps/app_name_web/config/test.exs"},
      {:eex,  "phx_umbrella/apps/app_name_web/test/test_helper.exs",    "apps/app_name_web/test/test_helper.exs"},
      {:eex,  "phx_umbrella/apps/app_name_web/lib/app_name_web.ex",     "apps/app_name_web/lib/app_name_web.ex"},
      {:eex,  "phx_umbrella/apps/app_name_web/lib/endpoint.ex",         "apps/app_name_web/lib/endpoint.ex"},
      {:eex,  "phx_umbrella/apps/app_name_web/lib/gettext.ex",          "apps/app_name_web/lib/gettext.ex"},
      {:eex,  "phx_umbrella/apps/app_name_web/lib/router.ex",           "apps/app_name_web/lib/router.ex"},
      {:eex,  "phx_umbrella/apps/app_name_web/README.md",               "apps/app_name_web/README.md"},
      {:eex,  "phx_umbrella/apps/app_name_web/mix.exs",                 "apps/app_name_web/mix.exs"},
      {:keep, "phx_umbrella/apps/app_name_web/test/channels",                  "apps/app_name_web/test/channels"},
      {:keep, "phx_umbrella/apps/app_name_web/test/controllers",               "apps/app_name_web/test/controllers"},
      {:eex,  "phx_umbrella/apps/app_name_web/test/views/error_view_test.exs", "apps/app_name_web/test/views/error_view_test.exs"},
      {:eex,  "phx_umbrella/apps/app_name_web/test/support/conn_case.ex",      "apps/app_name_web/test/support/conn_case.ex"},
      {:eex,  "phx_umbrella/apps/app_name_web/test/support/channel_case.ex",   "apps/app_name_web/test/support/channel_case.ex"},
      {:eex,  "phx_umbrella/apps/app_name_web/lib/channels/user_socket.ex",    "apps/app_name_web/lib/channels/user_socket.ex"},
      {:keep, "phx_umbrella/apps/app_name_web/lib/controllers",                "apps/app_name_web/lib/controllers"},
      {:eex,  "phx_umbrella/apps/app_name_web/lib/views/error_view.ex",        "apps/app_name_web/lib/views/error_view.ex"},
      {:eex,  "phx_umbrella/apps/app_name_web/lib/views/error_helpers.ex",     "apps/app_name_web/lib/views/error_helpers.ex"},
      {:eex,  "phx_umbrella/apps/app_name_web/priv/gettext/errors.pot",        "apps/app_name_web/priv/gettext/errors.pot"},
      {:eex,  "phx_umbrella/apps/app_name_web/priv/gettext/en/LC_MESSAGES/errors.po", "apps/app_name_web/priv/gettext/en/LC_MESSAGES/errors.po"},
    ]
  }

  @ecto %{
    regular: [
      {:eex,  "phx_ecto/repo.ex",              "lib/app_name/repo.ex"},
      {:eex,  "phx_ecto/data_case.ex",         "test/support/data_case.ex"},
      {:keep, "phx_ecto/priv/repo/migrations", "priv/repo/migrations"},
      {:eex,  "phx_ecto/seeds.exs",            "priv/repo/seeds.exs"}
    ],
    umbrella: [
      {:eex,  "phx_umbrella/apps/app_name/lib/repo.ex", "lib/repo.ex"},
      {:eex,  "phx_ecto/data_case.ex",                  "test/support/data_case.ex"},
      {:eex,  "phx_ecto/seeds.exs",                     "priv/repo/seeds.exs"},
      {:keep, "phx_umbrella/apps/app_name/priv/repo/migrations", "priv/repo/migrations"},
     ]
  }

  @brunch %{
    regular: [
      {:text, "assets/brunch/.gitignore",       ".gitignore"},
      {:eex,  "assets/brunch/brunch-config.js", "assets/brunch-config.js"},
      {:eex,  "assets/brunch/package.json",     "assets/package.json"},
      {:text, "assets/app.css",                 "assets/css/app.css"},
      {:text, "assets/phoenix.css",             "assets/css/phoenix.css"},
      {:eex,  "assets/brunch/app.js",           "assets/js/app.js"},
      {:eex,  "assets/brunch/socket.js",        "assets/js/socket.js"},
      {:keep, "assets/vendor",                  "assets/vendor"},
      {:text, "assets/robots.txt",              "assets/static/robots.txt"},
    ],
    umbrella: [
      {:text, "assets/brunch/.gitignore",       ".gitignore"},
      {:eex,  "assets/brunch/brunch-config.js", "assets/brunch-config.js"},
      {:eex,  "assets/brunch/package.json",     "assets/package.json"},
      {:text, "assets/app.css",                 "assets/css/app.css"},
      {:text, "assets/phoenix.css",             "assets/css/phoenix.css"},
      {:eex,  "assets/brunch/app.js",           "assets/js/app.js"},
      {:eex,  "assets/brunch/socket.js",        "assets/js/socket.js"},
      {:keep, "assets/vendor",                  "assets/vendor"},
      {:text, "assets/robots.txt",              "assets/static/robots.txt"},
    ]
  }

  @html %{
    regular: [
      {:eex,  "phx_new/test/controllers/page_controller_test.exs",       "test/controllers/page_controller_test.exs"},
      {:eex,  "phx_new/test/views/layout_view_test.exs",                 "test/views/layout_view_test.exs"},
      {:eex,  "phx_new/test/views/page_view_test.exs",                   "test/views/page_view_test.exs"},
      {:eex,  "phx_new/lib/app_name/web/controllers/page_controller.ex", "lib/app_name/web/controllers/page_controller.ex"},
      {:eex,  "phx_new/lib/app_name/web/templates/layout/app.html.eex",  "lib/app_name/web/templates/layout/app.html.eex"},
      {:eex,  "phx_new/lib/app_name/web/templates/page/index.html.eex",  "lib/app_name/web/templates/page/index.html.eex"},
      {:eex,  "phx_new/lib/app_name/web/views/layout_view.ex",           "lib/app_name/web/views/layout_view.ex"},
      {:eex,  "phx_new/lib/app_name/web/views/page_view.ex",             "lib/app_name/web/views/page_view.ex"},
    ],
    umbrella: [
      {:eex,  "phx_new/test/controllers/page_controller_test.exs",       "test/controllers/page_controller_test.exs"},
      {:eex,  "phx_new/test/views/layout_view_test.exs",                 "test/views/layout_view_test.exs"},
      {:eex,  "phx_new/test/views/page_view_test.exs",                   "test/views/page_view_test.exs"},
      {:eex,  "phx_new/lib/app_name/web/controllers/page_controller.ex", "lib/controllers/page_controller.ex"},
      {:eex,  "phx_new/lib/app_name/web/templates/layout/app.html.eex",  "lib/templates/layout/app.html.eex"},
      {:eex,  "phx_new/lib/app_name/web/templates/page/index.html.eex",  "lib/templates/page/index.html.eex"},
      {:eex,  "phx_new/lib/app_name/web/views/layout_view.ex",           "lib/views/layout_view.ex"},
      {:eex,  "phx_new/lib/app_name/web/views/page_view.ex",             "lib/views/page_view.ex"},
    ]
  }

  @bare %{
    regular:  [{:text,   "static/bare/.gitignore", ".gitignore"}],
    umbrella: [{:text,   "static/bare/.gitignore", ".gitignore"}]
  }

  @static %{
    regular: [
      {:text,   "assets/bare/.gitignore", ".gitignore"},
      {:text,   "assets/app.css",         "priv/static/css/app.css"},
      {:append, "assets/phoenix.css",     "priv/static/css/app.css"},
      {:text,   "assets/bare/app.js",     "priv/static/js/app.js"},
      {:text,   "assets/robots.txt",      "priv/static/robots.txt"},
    ],
    umbrella: [
      {:text,   "assets/bare/.gitignore", ".gitignore"},
      {:text,   "assets/app.css",         "apps/app_name_web/priv/static/css/app.css"},
      {:append, "assets/phoenix.css",     "apps/app_name_web/priv/static/css/app.css"},
      {:text,   "assets/bare/app.js",     "apps/app_name_web/priv/static/js/app.js"},
      {:text,   "assets/robots.txt",      "apps/app_name_web/priv/static/robots.txt"},
    ]
  }

  # Embed all defined templates
  root = Path.expand("../templates", __DIR__)
  templates =
    [@new, @ecto, @brunch, @html, @static, @bare]
    |> Enum.flat_map(fn template -> template.regular ++ template.umbrella end)

  for {format, source, _} <- templates, format != :keep do
    path = Path.join(root, source)
    unless path in @external_resource do
      @external_resource path
      def render(unquote(source)), do: unquote(File.read!(path))
    end
  end

  # Embed missing files from Phoenix static.
  embed_text :phoenix_js, from_file: Path.expand("../../priv/static/phoenix.js", __DIR__)
  embed_text :phoenix_png, from_file: Path.expand("../../priv/static/phoenix.png", __DIR__)
  embed_text :phoenix_favicon, from_file: Path.expand("../../priv/static/favicon.ico", __DIR__)

  @moduledoc """
  Creates a new Phoenix project.

  It expects the path of the project as argument.

      mix phx.new PATH [--module MODULE] [--app APP]

  A project at the given PATH will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.

  ## Options

    * `--app` - the name of the OTP application

    * `--module` - the name of the base module in
      the generated skeleton

    * `--database` - specify the database adapter for ecto.
      Values can be `postgres`, `mysql`, `mssql`, `sqlite` or
      `mongodb`. Defaults to `postgres`

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

      mix phx.new hello_world

  Is equivalent to:

      mix phx.new hello_world --module HelloWorld

  Without brunch:

      mix phx.new ~/Workspace/hello_world --no-brunch

  """
  @switches [dev: :boolean, brunch: :boolean, ecto: :boolean,
             app: :string, module: :string, database: :string,
             binary_id: :boolean, html: :boolean, umbrella: :boolean]

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
        Mix.Task.run "help", ["phx.new"]
      [path | _] ->
        project_type = if opts[:umbrella], do: :umbrella, else: :regular
        app = opts[:app] || Path.basename(Path.expand(path))
        project_path = project_path(path, project_type)
        check_app_name!(app, !!opts[:app])
        check_directory_existence!(path)
        mod = opts[:module] || Macro.camelize(app)
        check_module_name_validity!(mod)
        check_module_name_availability!(mod)

        run(project_type, app, mod, project_path, opts)
    end
  end
  defp project_path(path, :regular), do: path
  defp project_path(path, :umbrella), do: path <> "_umbrella"

  def run(project_type, app, mod, path, opts) do
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
    in_umbrella? = in_umbrella?(path, project_type)
    brunch_deps_prefix = if in_umbrella?, do: "../../../", else: "../"
    web_namespace = web_namespace(project_type, mod)

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

    binding = [application_name: app,
               umbrella_module: inspect(Module.concat(mod, Umbrella)),
               web_application_name: web_application_name(project_type, app),
               application_module: mod,
               endpoint_module: inspect(Module.concat(web_namespace, Endpoint)),
               web_namespace: inspect(web_namespace),
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

    copy_from path, binding, @new[project_type]

    # Optional contents
    web_path = web_path(project_type, app, path)
    ecto_path = ecto_path(project_type, app, path)

    copy_ecto(project_type, app, ecto_path, binding)
    copy_static(project_type, app, web_path, binding)
    copy_html(project_type, app, web_path, binding)

    # Parallel installs
    install? = Mix.shell.yes?("\nFetch and install dependencies?")

    File.cd!(path, fn ->
      mix? = install_mix(install?)
      File.cd!(Path.join("..", web_path), fn ->
        brunch? = install_brunch(install?)
        extra   = if mix?, do: [], else: ["$ mix deps.get"]

        print_mix_info(path, extra)

        if binding[:ecto], do: print_ecto_info()

        if not brunch?, do: print_brunch_info()
      end)
    end)
  end

  defp web_path(:regular, app, path), do: String.replace(path, "app_name", app)
  defp web_path(:umbrella, app, path),
    do: Path.join(path, "apps/#{web_application_name(:umbrella, app)}/")

  defp ecto_path(:regular, _app, path), do: path
  defp ecto_path(:umbrella, app, path), do: Path.join(path, "apps/#{app}/")

  defp web_namespace(:regular, app_mod), do: Module.concat(app_mod, Web)
  defp web_namespace(:umbrella, app_mod), do: Module.concat(app_mod, Web)

  defp web_application_name(:regular, app_name), do: app_name
  defp web_application_name(:umbrella, app_name), do: :"#{app_name}_web"

  defp switch_to_string({name, nil}), do: name
  defp switch_to_string({name, val}), do: name <> "=" <> val

  defp copy_ecto(project_type, _app_name, path, binding) do
    if binding[:ecto] do
      copy_from path, binding, @ecto[project_type]

      adapter_config = binding[:adapter_config]

      append_to path, "config/dev.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:dev]},
        pool_size: 10
      """

      append_to path, "config/test.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:test]}
      """

      append_to path, "config/prod.secret.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]}#{kw_to_config adapter_config[:prod]},
        pool_size: 20
      """
    end
  end

  defp get_generator_config(adapter_config) do
    adapter_config
    |> Keyword.take([:binary_id, :migration, :sample_binary_id])
    |> Enum.filter(fn {_, value} -> not is_nil(value) end)
  end

  defp copy_static(project_type, _app, path, binding) do
    case {binding[:brunch], binding[:html]} do
      {true, _} ->
        copy_from path, binding, @brunch[project_type]
        create_file Path.join(path, "assets/static/images/phoenix.png"), phoenix_png_text()
        create_file Path.join(path, "assets/static/favicon.ico"), phoenix_favicon_text()
      {false, true} ->
        copy_from path, binding, @static[project_type]
        create_file Path.join(path, "priv/static/js/phoenix.js"), phoenix_js_text()
        create_file Path.join(path, "priv/static/images/phoenix.png"), phoenix_png_text()
        create_file Path.join(path, "priv/static/favicon.ico"), phoenix_favicon_text()
      {false, false} ->
        copy_from path, binding, @bare[project_type]
    end
  end

  defp copy_html(project_type, _app, path, binding) do
    if binding[:html] do
      copy_from path, binding, @html[project_type]
    end
  end

  defp install_brunch(install?) do
    maybe_cmd "cd assets && npm install && node node_modules/brunch/bin/brunch build",
              File.exists?("assets/brunch-config.js"), install? && System.find_executable("npm")

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

  defp maybe_cmd(cmd, should_run?, can_run?, cmd_opts \\ []) do
    cond do
      should_run? && can_run? ->
        cmd(cmd, cmd_opts)
        true
      should_run? ->
        false
      true ->
        true
    end
  end

  defp cmd(cmd, cmd_opts) do
    Mix.shell.info [:green, "* running ", :reset, cmd]
    case Mix.shell.cmd(cmd, Keyword.merge([quiet: false], cmd_opts)) do
      0 ->
        true
      _ ->
        Mix.shell.error [:red, "* error ", :reset, "command failed to execute, " <>
          "please run the following command again after installation: \"#{cmd}\""]
        false
    end
  end

  defp check_app_name!(name, from_app_flag) do
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

  def check_directory_existence!(path) do
    if File.dir?(path) && !Mix.shell.yes?("The directory #{path} already exists. Are you sure you want to continue?") do
      Mix.raise "Please select another directory for installation."
    end
  end

  defp get_ecto_adapter("mssql", app, module) do
    {:tds_ecto, Tds.Ecto, db_config(app, module, "db_user", "db_password")}
  end
  defp get_ecto_adapter("mysql", app, module) do
    {:mariaex, Ecto.Adapters.MySQL, db_config(app, module, "root", "")}
  end
  defp get_ecto_adapter("postgres", app, module) do
    {:postgrex, Ecto.Adapters.Postgres, db_config(app, module, "postgres", "postgres")}
  end
  defp get_ecto_adapter("sqlite", app, module) do
    {:sqlite_ecto, Sqlite.Ecto,
     dev:  [database: "db/#{app}_dev.sqlite"],
     test: [database: "db/#{app}_test.sqlite", pool: Ecto.Adapters.SQL.Sandbox],
     prod: [database: "db/#{app}_prod.sqlite"],
     test_setup_all: "Ecto.Adapters.SQL.Sandbox.mode(#{module}.Repo, :manual)",
     test_setup: ":ok = Ecto.Adapters.SQL.Sandbox.checkout(#{module}.Repo)",
     test_async: "Ecto.Adapters.SQL.Sandbox.mode(#{module}.Repo, {:shared, self()})"}
  end
  defp get_ecto_adapter("mongodb", app, module) do
    {:mongodb_ecto, Mongo.Ecto,
     dev:  [database: "#{app}_dev"],
     test: [database: "#{app}_test", pool_size: 1],
     prod: [database: "#{app}_prod"],
     test_setup_all: "",
     test_setup: "",
     test_async: "Mongo.Ecto.truncate(#{module}.Repo, [])",
     binary_id: true,
     migration: false,
     sample_binary_id: "111111111111111111111111"}
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

  defp in_umbrella?(_app_path, :umbrella), do: true
  defp in_umbrella?(app_path, :regular) do
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

  defp phoenix_dep("deps/phoenix"), do: ~s[{:phoenix, "~> 1.2.0"}]
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
    app_name = Keyword.fetch!(binding, :application_name)
    for {format, source, target_path} <- mapping do
      target = Path.join(target_dir,
                         String.replace(target_path, "app_name", app_name))

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
