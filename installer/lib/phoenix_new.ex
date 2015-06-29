defmodule Mix.Tasks.Phoenix.New do
  use Mix.Task
  import Mix.Generator

  @phoenix Path.expand("../..", __DIR__)
  @version Mix.Project.config[:version]
  @shortdoc "Create a new Phoenix v#{@version} application"

  # File mappings

  @new [
    {:eex,  "new/config/config.exs",                         "config/config.exs"},
    {:eex,  "new/config/dev.exs",                            "config/dev.exs"},
    {:eex,  "new/config/prod.exs",                           "config/prod.exs"},
    {:eex,  "new/config/prod.secret.exs",                    "config/prod.secret.exs"},
    {:eex,  "new/config/test.exs",                           "config/test.exs"},
    {:eex,  "new/lib/application_name.ex",                   "lib/application_name.ex"},
    {:eex,  "new/lib/application_name/endpoint.ex",          "lib/application_name/endpoint.ex"},
    {:keep, "new/test/channels",                             "test/channels"},
    {:eex,  "new/test/controllers/page_controller_test.exs", "test/controllers/page_controller_test.exs"},
    {:eex,  "new/test/views/error_view_test.exs",            "test/views/error_view_test.exs"},
    {:eex,  "new/test/views/page_view_test.exs",             "test/views/page_view_test.exs"},
    {:eex,  "new/test/support/conn_case.ex",                 "test/support/conn_case.ex"},
    {:eex,  "new/test/support/channel_case.ex",              "test/support/channel_case.ex"},
    {:eex,  "new/test/test_helper.exs",                      "test/test_helper.exs"},
    {:keep, "new/web/channels",                              "web/channels"},
    {:eex,  "new/web/controllers/page_controller.ex",        "web/controllers/page_controller.ex"},
    {:keep, "new/web/models",                                "web/models"},
    {:eex,  "new/web/templates/layout/app.html.eex",         "web/templates/layout/app.html.eex"},
    {:eex,  "new/web/templates/page/index.html.eex",         "web/templates/page/index.html.eex"},
    {:eex,  "new/web/views/error_view.ex",                   "web/views/error_view.ex"},
    {:eex,  "new/web/views/layout_view.ex",                  "web/views/layout_view.ex"},
    {:eex,  "new/web/views/page_view.ex",                    "web/views/page_view.ex"},
    {:eex,  "new/web/router.ex",                             "web/router.ex"},
    {:eex,  "new/web/web.ex",                                "web/web.ex"},
    {:eex,  "new/mix.exs",                                   "mix.exs"},
    {:eex,  "new/README.md",                                 "README.md"},
  ]

  @ecto [
    {:eex,  "ecto/repo.ex",              "lib/application_name/repo.ex"},
    {:keep, "ecto/test/models",          "test/models"},
    {:eex,  "ecto/model_case.ex",        "test/support/model_case.ex"},
    {:keep, "ecto/priv/repo/migrations", "priv/repo/migrations"}
  ]

  @brunch [
    {:text, "static/brunch/.gitignore",       ".gitignore"},
    {:text, "static/brunch/brunch-config.js", "brunch-config.js"},
    {:text, "static/brunch/package.json",     "package.json"},
    {:text, "static/app.css",                 "web/static/css/app.scss"},
    {:text, "static/brunch/app.js",           "web/static/js/app.js"},
    {:text, "static/robots.txt",              "web/static/assets/robots.txt"},
  ]

  @bare [
    {:text, "static/bare/.gitignore", ".gitignore"},
    {:text, "static/app.css",         "priv/static/css/app.css"},
    {:text, "static/bare/app.js",     "priv/static/js/app.js"},
    {:text, "static/robots.txt",      "priv/static/robots.txt"},
  ]

  # Embed all defined templates
  root = Path.expand("../templates", __DIR__)

  for {format, source, _} <- @new ++ @ecto ++ @brunch ++ @bare do
    unless format == :keep do
      @external_resource Path.join(root, source)
      def render(unquote(source)), do: unquote(File.read!(Path.join(root, source)))
    end
  end

  # Embed missing files from Phoenix static.
  embed_text :phoenix_js, from_file: Path.expand("../../priv/static/phoenix.js", __DIR__)
  embed_text :phoenix_png, from_file: Path.expand("../../priv/static/phoenix.png", __DIR__)
  embed_text :phoenix_favicon, from_file: Path.expand("../../priv/static/favicon.ico", __DIR__)

  @moduledoc """
  Creates a new Phoenix project.

  It expects the path of the project as argument.

      mix phoenix.new PATH [--module MODULE] [--app APP]

  A project at the given PATH  will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.

  ## Options

    * `--app` - the name of the OTP application

    * `--module` - the name of the base module in
      the generated skeleton

    * `--database` - specify the database adapter for ecto.
      Values can be `mysql` or `mssql`. Defaults to `postgres`

    * `--no-brunch` - do not generate brunch files
      for static asset building

    * `--no-ecto` - do not generate ecto files for
      the model layer

  ## Examples

      mix phoenix.new hello_world

  Is equivalent to:

      mix phoenix.new hello_world --module HelloWorld

  Without brunch:

      mix phoenix.new ~/Workspace/hello_world --no-brunch

  """
  @switches [dev: :boolean, brunch: :boolean, ecto: :boolean,
             app: :string, module: :string, database: :string]

  def run([version]) when version in ~w(-v --version) do
    Mix.shell.info "Phoenix v#{@version}"
  end

  def run(argv) do
    {opts, argv, _} = OptionParser.parse(argv, switches: @switches)

    case argv do
      [] ->
        Mix.raise "Expected PATH to be given, please use `mix phoenix.new PATH`"
      [path|_] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !!opts[:app])
        mod = opts[:module] || Mix.Utils.camelize(app)
        check_module_name_validity!(mod)
        check_module_name_availability!(mod)

        run(app, mod, path, opts)
    end
  end

  def run(app, mod, path, opts) do
    db = Keyword.get(opts, :database, "postgres")
    dev = Keyword.get(opts, :dev, false)
    ecto = Keyword.get(opts, :ecto, true)
    brunch = Keyword.get(opts, :brunch, true)

    {adapter_app, adapter_module, db_user, db_password} = set_ecto_adapter(db)
    pubsub_server = set_pubsub_server(mod)

    binding = [application_name: app,
               application_module: mod,
               phoenix_dep: phoenix_dep(dev),
               pubsub_server: pubsub_server,
               secret_key_base: random_string(64),
               prod_secret_key_base: random_string(64),
               signing_salt: random_string(8),
               in_umbrella: in_umbrella?(path),
               brunch: brunch,
               ecto: ecto,
               adapter_app: adapter_app,
               adapter_module: adapter_module,
               db_user: db_user,
               db_password: db_password,
               hex?: Code.ensure_loaded?(Hex),
               namespaced?: Mix.Utils.camelize(app) != mod]

    copy_from path, binding, @new

    # Optional contents
    copy_model  app, path, binding
    copy_static app, path, binding

    # Parallel installs
    install? = Mix.shell.yes?("\nFetch and install dependencies?")

    File.cd!(path, fn ->
      brunch =
        case install_brunch(install?) do
          {:ok, task}   -> task
          :not_required -> nil
          :not_allowed  -> print_brunch_info()
        end

      {mix, extra} =
        case install_mix(install?) do
          {:ok, task}  -> {task, []}
          :not_allowed -> {nil, ["$ mix deps.get"]}
        end

      brunch && Task.await(brunch, :infinity)
      mix    && Task.await(mix, :infinity)

      print_mix_info(path, extra)
    end)
  end

  defp copy_model(_app, path, binding) do
    if binding[:ecto] do
      copy_from path, binding, @ecto

      append_to path, "config/dev.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]},
        username: #{inspect binding[:db_user]},
        password: #{inspect binding[:db_password]},
        database: "#{binding[:application_name]}_dev",
        size: 10 # The amount of database connections in the pool
      """

      append_to path, "config/test.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]},
        username: #{inspect binding[:db_user]},
        password: #{inspect binding[:db_password]},
        database: "#{binding[:application_name]}_test",
        pool: Ecto.Adapters.SQL.Sandbox, # Use a sandbox for transactional testing
        size: 1
      """

      append_to path, "config/prod.secret.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: #{inspect binding[:adapter_module]},
        username: #{inspect binding[:db_user]},
        password: #{inspect binding[:db_password]},
        database: "#{binding[:application_name]}_prod",
        size: 20 # The amount of database connections in the pool
      """
    end
  end

  defp copy_static(_app, path, binding) do
    if binding[:brunch] == false do
      copy_from path, binding, @bare
      create_file Path.join(path, "priv/static/js/phoenix.js"), phoenix_js_text()
      create_file Path.join(path, "priv/static/images/phoenix.png"), phoenix_png_text()
      create_file Path.join(path, "priv/static/images/favicon.ico"), phoenix_favicon_text()
    else
      copy_from path, binding, @brunch
      create_file Path.join(path, "web/static/vendor/phoenix.js"), phoenix_js_text()
      create_file Path.join(path, "web/static/assets/images/phoenix.png"), phoenix_png_text()
      create_file Path.join(path, "web/static/assets/images/favicon.ico"), phoenix_favicon_text()
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

  defp print_mix_info(path, extra) do
    steps = ["$ cd #{path}"] ++ extra ++ ["$ mix phoenix.server"]

    Mix.shell.info """

    We are all set! Run your Phoenix application:

        #{Enum.join(steps, "\n    ")}

    You can also run it inside IEx (Interactive Elixir) as:

        $ iex -S mix phoenix.server
    """
  end

  ## Helpers

  defp maybe_cmd(cmd, should_run?, can_run?) do
    cond do
      should_run? && can_run? ->
        {:ok, cmd(cmd)}
      should_run? ->
        :not_allowed
      true ->
        :not_required
    end
  end

  defp cmd(cmd) do
    Mix.shell.info [:green, "* running ", :reset, cmd]
    Task.async(fn ->
      # We use :os.cmd/1 because there is a bug in OTP
      # where we cannot execute .cmd files on Windows.
      # We could use Mix.shell.cmd/1 but that automatically
      # outputs to the terminal and we don't want that.
      :os.cmd(String.to_char_list(cmd))
    end)
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

  defp set_ecto_adapter("mssql"), do: {:tds_ecto, Tds.Ecto, "db_user", "db_password"}
  defp set_ecto_adapter("mysql"), do: {:mariaex, Ecto.Adapters.MySQL, "root", ""}
  defp set_ecto_adapter("postgres"), do: {:postgrex, Ecto.Adapters.Postgres, "postgres", "postgres"}
  defp set_ecto_adapter(db), do: Mix.raise "Unknown database #{inspect db}"

  defp set_pubsub_server(module) do
    module
    |> String.split(".")
    |> hd
    |> Module.concat(PubSub)
  end

  defp in_umbrella?(app_path) do
    umbrella = Path.expand(Path.join [app_path, "..", ".."])

    try do
      File.exists?(Path.join(umbrella, "mix.exs")) &&
        Mix.Project.in_project(:umbrella_check, umbrella, fn _ ->
          path = Mix.Project.config[:apps_path]
          path && Path.expand(path) == Path.join(umbrella, "apps")
        end)
    catch
      _, _ -> false
    end
  end

  defp phoenix_dep(true), do: ~s[{:phoenix, path: #{inspect @phoenix}, override: true}]
  defp phoenix_dep(_),    do: ~s[{:phoenix, github: "phoenixframework/phoenix", override: true}]

  defp random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
  end

  ## Template helpers

  defp copy_from(target_dir, binding, mapping) when is_list(mapping) do
    application_name = Keyword.fetch!(binding, :application_name)
    for {format, source, target_path} <- mapping do
      target = Path.join(target_dir,
                         String.replace(target_path, "application_name", application_name))

      case format do
        :keep ->
          File.mkdir_p!(target)
        :text ->
          create_file(target, render(source))
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
