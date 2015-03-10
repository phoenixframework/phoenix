defmodule Mix.Tasks.Phoenix.New do
  use Mix.Task
  alias Phoenix.Naming

  @shortdoc "Create a new Phoenix application"

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

  @brunch [
    {:text, "brunch/.gitignore",       ".gitignore"},
    {:text, "brunch/brunch-config.js", "brunch-config.js"},
    {:text, "brunch/package.json",     "package.json"},
    {:text, "images/phoenix.png",      "priv/static/images/phoenix.png"},
    {:text, "app.css",                 "web/static/css/app.scss"},
    {:text, "brunch/app.js",           "web/static/js/app.js"},
    {:text, "phoenix.js",              "web/static/vendor/phoenix.js"},
  ]

  @bare [
    {:text, "bare/.gitignore",    ".gitignore"},
    {:text, "app.css",            "priv/static/css/app.css"},
    {:text, "images/phoenix.png", "priv/static/images/phoenix.png"},
    {:text, "bare/app.js",        "priv/static/js/app.js"},
    {:text, "phoenix.js",         "priv/static/js/phoenix.js"},
  ]

  @switches [dev: :boolean, brunch: :boolean, ecto: :boolean]

  def run(argv) do
    {opts, argv, _} = OptionParser.parse(argv, switches: @switches)

    case argv do
      [] ->
        Mix.raise "Expected PATH to be given, please use `mix phoenix.new PATH`"
      [path|_] ->
        app    = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !!opts[:app])
        mod = opts[:module] || Naming.camelize(app)
        check_module_name!(mod)

        run(app, mod, path, opts)
    end
  end

  def run(app, mod, path, opts) do
    dev = Keyword.get(opts, :dev, false)
    ecto = Keyword.get(opts, :ecto, true)
    brunch = Keyword.get(opts, :brunch, true)

    pubsub_server = [mod]
                    |> Module.concat()
                    |> Naming.base_concat(PubSub)

    binding = [application_name: app,
               application_module: mod,
               phoenix_dep: phoenix_dep(dev),
               pubsub_server: pubsub_server,
               secret_key_base: random_string(64),
               prod_secret_key_base: random_string(64),
               encryption_salt: random_string(8),
               signing_salt: random_string(8),
               in_umbrella: in_umbrella?(path),
               brunch: brunch,
               ecto: ecto]

    copy_wildcard templates_dir("new"), path, app, binding

    # Optional contents
    copy_model  app, path, binding
    copy_static app, path, binding

    # Parallel installs
    install_parallel path, binding

    # All set!
    Mix.shell.info """

    We are all set! Run your Phoenix application:

        $ cd #{path}
        $ mix phoenix.server

    You can also run it inside IEx (Interactive Elixir) as:

        $ iex -S mix phoenix.server
    """
  end

  defp copy_model(app, path, binding) do
    if binding[:ecto] do
      copy_wildcard templates_dir("ecto"), path, app, binding

      append_to path, "config/dev.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: Ecto.Adapters.Postgres,
        username: "postgres",
        password: "postgres",
        database: "#{binding[:application_name]}_dev"
      """

      append_to path, "config/test.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: Ecto.Adapters.Postgres,
        username: "postgres",
        password: "postgres",
        database: "#{binding[:application_name]}_test",
        size: 1,
        max_overflow: false
      """

      append_to path, "config/prod.secret.exs", """

      # Configure your database
      config :#{binding[:application_name]}, #{binding[:application_module]}.Repo,
        adapter: Ecto.Adapters.Postgres,
        username: "postgres",
        password: "postgres",
        database: "#{binding[:application_name]}_prod"
      """
    end
  end

  defp copy_static(_app, path, binding) do
    if binding[:brunch] do
      Mix.Phoenix.copy_from priv_dir("static"), path, [], @brunch
    else
      Mix.Phoenix.copy_from priv_dir("static"), path, [], @bare
    end
  end

  defp install_parallel(path, binding) do
    File.cd!(path, fn ->
      mix    = install_mix(binding)
      brunch = install_brunch(binding)

      brunch && Task.await(brunch, :infinity)
      mix    && Task.await(mix, :infinity)
    end)
  end

  defp install_brunch(binding) do
    task = binding[:brunch] &&
           ask_and_run("Install brunch.io dependencies?", "npm", "install")

    unless task do
      Mix.shell.info """

      Brunch was setup for static assets, but node deps were not
      installed via npm. Installation instructions for nodejs,
      which includes npm, can be found at http://nodejs.org

      Install your brunch dependencies by running inside your app:

          $ npm install
      """
    end

    task
  end

  defp install_mix(_) do
    ask_and_run("Install mix dependencies?", "mix", "deps.get")
  end

  ## Specific functions

  # Copies all contents in source dir to target dir.
  # If application_name is seen in the path, it is
  # replaced by the actual application name.
  defp copy_wildcard(source_dir, target_dir, application_name, binding) do
    source_paths =
      source_dir
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)

    for source_path <- source_paths do
      target_path = make_destination_path(source_path, source_dir,
                                          target_dir, application_name)

      cond do
        File.dir?(source_path) ->
          File.mkdir_p!(target_path)
        Path.basename(source_path) == ".keep" ->
          :ok
        true ->
          contents = EEx.eval_file(source_path, binding)
          Mix.Generator.create_file(target_path, contents)
      end
    end

    :ok
  end

  defp make_destination_path(source_path, source_dir, target_dir, application_name) do
    target_path =
      source_path
      |> String.replace("application_name", application_name)
      |> Path.relative_to(source_dir)
    Path.join(target_dir, target_path)
  end

  defp append_to(path, file, contents) do
    file = Path.join(path, file)
    File.write!(file, File.read!(file) <> contents)
  end

  ## Helpers

  defp ask_and_run(question, command, args) do
    if System.find_executable(command) &&
       Mix.shell.yes?("\n" <> question) do
      exec = command <> " " <> args
      Mix.shell.info [:green, "* running ", :reset, exec]
      Task.async(fn ->
        # We use :os.cmd/1 because there is a bug in OTP
        # where we cannot execute .cmd files on Windows.
        # We could use Mix.shell.cmd/1 but that automatically
        # outputs to the terminal and we don't want that.
        :os.cmd(String.to_char_list(exec))
      end)
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

  defp check_module_name!(name) do
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect name}"
    end
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

  defp phoenix_dep(true), do: ~s[{:phoenix, path: #{inspect File.cwd!}, override: true}]
  defp phoenix_dep(_),    do: ~s[{:phoenix, github: "phoenixframework/phoenix", override: true}]

  defp random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
  end

  defp priv_dir(dir) do
    Application.app_dir(:phoenix, Path.join("priv", dir))
  end

  defp templates_dir(dir) do
    priv_dir(Path.join("templates", dir))
  end
end
