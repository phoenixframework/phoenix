defmodule Mix.Tasks.Phx.New do
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
  use Mix.Task
  import Mix.Generator
  import Mix.Tasks.Phx.New.Generator
  alias Mix.Tasks.Phx.New.{Single, Umbrella}

  @phoenix Path.expand("../..", __DIR__)
  @version Mix.Project.config[:version]
  @shortdoc "Creates a new Phoenix v#{@version} application using the experimental generators"


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
    {opts, argv} = parse_opts(argv)

    case argv do
      [] ->
        Mix.Task.run "help", ["phx.new"]
      [base_path | _] ->
        generator = if opts[:umbrella], do: Umbrella, else: Single
        {app, app_mod, app_path} = generator.app(base_path, opts)
        {root_app, root_mod, project_path} = generator.root_app(app, base_path, opts)

        check_app_name!(app, !!opts[:app])
        check_directory_existence!(project_path)
        check_module_name_validity!(root_mod)
        check_module_name_availability!(root_mod)

        run(generator, root_app, root_mod, app, app_mod, app_path, project_path, opts)
    end
  end

  def run(generator, root_app, root_mod, app, app_mod, app_path, proj_path, opts) do
    {web_app_name, web_namespace, web_path} = generator.web_app(app, proj_path, opts)
    db = Keyword.get(opts, :database, "postgres")
    ecto = Keyword.get(opts, :ecto, true)
    html = Keyword.get(opts, :html, true)
    brunch = Keyword.get(opts, :brunch, true)
    phoenix_path = phoenix_path(proj_path, Keyword.get(opts, :dev, false))

    # We lowercase the database name because according to the
    # SQL spec, they are case insensitive unless quoted, which
    # means creating a database like FoO is the same as foo in
    # some storages.
    {adapter_app, adapter_module, adapter_config} = get_ecto_adapter(db, String.downcase(app), app_mod)
    pubsub_server = get_pubsub_server(app_mod)
    in_umbrella? = in_umbrella?(proj_path, generator)
    brunch_deps_prefix = if in_umbrella?, do: "../../../", else: "../"

    adapter_config =
      case Keyword.fetch(opts, :binary_id) do
        {:ok, value} -> Keyword.put_new(adapter_config, :binary_id, value)
        :error -> adapter_config
      end
    generator_config = generator_config(adapter_config)

    binding = [app_name: app,
               app_module: inspect(app_mod),
               root_app_name: root_app,
               root_app_module: inspect(root_mod),
               web_app_name: web_app_name,
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
               namespaced?: Macro.camelize(app) != app_mod]

    generator.gen_new(proj_path, app, binding)
    copy_ecto(generator, app_path, app, binding)
    copy_static(generator, web_path, app, binding)
    copy_html(generator, web_path, app, binding)

    install? = Mix.shell.yes?("\nFetch and install dependencies?")

    File.cd!(proj_path, fn ->
      mix? = install_mix(install?)
      File.cd!(web_path, fn ->
        brunch? = install_brunch(install?)
        extra   = if mix?, do: [], else: ["$ mix deps.get"]

        print_mix_info(proj_path, extra)

        if binding[:ecto], do: print_ecto_info()

        if not brunch?, do: print_brunch_info()
      end)
    end)
  end

  defp parse_opts(argv) do
    case OptionParser.parse(argv, strict: @switches) do
      {opts, argv, []} ->
        {opts, argv}
      {_opts, _argv, [switch | _]} ->
        Mix.raise "Invalid option: " <> switch_to_string(switch)
    end
  end
  defp switch_to_string({name, nil}), do: name
  defp switch_to_string({name, val}), do: name <> "=" <> val

  defp copy_ecto(generator, app_path, app_name, binding) do
    if binding[:ecto] do
      generator.gen_ecto(app_path, app_name, binding)

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
        pool_size: 20
      """
    end
  end

  defp generator_config(adapter_config) do
    adapter_config
    |> Keyword.take([:binary_id, :migration, :sample_binary_id])
    |> Enum.filter(fn {_, value} -> not is_nil(value) end)
    |> case do
      []               -> nil
      conf ->
        """

        # Configure phoenix generators
        config :phoenix, :generators#{kw_to_config(conf)}
        """
    end
  end

  defp copy_static(generator, web_path, app, binding) do
    case {binding[:brunch], binding[:html]} do
      {true, _} ->
        generator.gen_brunch(web_path, app, binding)
      {false, true} ->
        generator.gen_static(web_path, app, binding)
      {false, false} ->
        generator.gen_bare(web_path, app, binding)
    end
  end

  defp copy_html(generator, path, app, binding) do
    if binding[:html] do
      generator.gen_html(path, app, binding)
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
    steps = ["$ cd #{relative_app_path(path)}"] ++ extra ++ ["$ mix phoenix.server"]

    Mix.shell.info """

    We are all set! Run your Phoenix application:

        #{Enum.join(steps, "\n    ")}

    You can also run your app inside IEx (Interactive Elixir) as:

        $ iex -S mix phoenix.server
    """
  end
  defp relative_app_path(path) do
    case Path.relative_to_cwd(path) do
      ^path -> Path.basename(path)
      rel   -> rel
    end
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
    unless inspect(name) =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
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
    |> Module.split()
    |> hd()
    |> Module.concat(PubSub)
  end

  defp in_umbrella?(_app_path, Umbrella), do: true
  defp in_umbrella?(app_path, Single) do
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
    |> Path.split()
    |> Enum.map(fn _ -> ".." end)
    |> Path.join()
  end

  defp phoenix_path(_path, false) do
    "deps/phoenix"
  end
end
