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
    {:eex,  "new/test/controllers/page_controller_test.exs", "test/controllers/page_controller_test.exs"},
    {:eex,  "new/test/views/error_view_test.exs",            "test/views/error_view_test.exs"},
    {:eex,  "new/test/views/page_view_test.exs",             "test/views/page_view_test.exs"},
    {:eex,  "new/test/support/conn_case.ex",                 "test/support/conn_case.ex"},
    {:eex,  "new/test/test_helper.exs",                      "test/test_helper.exs"},
    {:keep, "new/web/channels",                              "web/channels"},
    {:eex,  "new/web/controllers/page_controller.ex",        "web/controllers/page_controller.ex"},
    {:keep, "new/web/models",                                "web/models"},
    {:eex,  "new/web/templates/layout/application.html.eex", "web/templates/layout/application.html.eex"},
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
    {:eex,  "ecto/repo.ex",         "lib/application_name/repo.ex"},
    {:keep, "priv/repo/migrations", "priv/repo/migrations"}
  ]

  @brunch [
    {:text, "static/brunch/.gitignore",       ".gitignore"},
    {:text, "static/brunch/brunch-config.js", "brunch-config.js"},
    {:text, "static/brunch/package.json",     "package.json"},
    {:text, "static/app.css",                 "web/static/css/app.scss"},
    {:text, "static/brunch/app.js",           "web/static/js/app.js"},
  ]

  @bare [
    {:text, "static/bare/.gitignore", ".gitignore"},
    {:text, "static/app.css",         "priv/static/css/app.css"},
    {:text, "static/bare/app.js",     "priv/static/js/app.js"},
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
  @switches [dev: :boolean, brunch: :boolean, ecto: :boolean]

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
        check_module_name!(mod)

        run(app, mod, path, opts)
    end
  end

  def run(app, mod, path, opts) do
    dev = Keyword.get(opts, :dev, false)
    ecto = Keyword.get(opts, :ecto, true)
    brunch = Keyword.get(opts, :brunch, true)

    pubsub_server = mod
                    |> String.split(".")
                    |> hd
                    |> Module.concat(PubSub)

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

    copy_from path, binding, @new

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

  defp copy_model(_app, path, binding) do
    if binding[:ecto] do
      copy_from path, binding, @ecto

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

  @brunch_question String.rstrip """

  Phoenix uses an optional build tool called brunch.io that
  requires npm but you don't have npm in your system. Would
  you still like to copy brunch.io files?
  """

  @brunch_install """

  Brunch was setup for static assets, but dependencies were
  not installed via npm. Installation instructions for node.js,
  which includes npm, can be found at http://nodejs.org.

  Install your brunch dependencies by running inside your app:

      $ npm install
  """

  defp copy_static(_app, path, binding) do
    brunch? =
      cond do
        binding[:brunch] == false ->
          false
        !System.find_executable("npm") ->
          if Mix.shell.yes?(@brunch_question) do
            Mix.shell.info(@brunch_install)
            true
          else
            Mix.shell.info("")
            false
          end
        true ->
          true
      end

    if brunch? do
      copy_from path, binding, @brunch
      create_file Path.join(path, "web/static/vendor/phoenix.js"), phoenix_js_text()
      create_file Path.join(path, "priv/static/images/phoenix.png"), phoenix_png_text()
    else
      copy_from path, binding, @bare
      create_file Path.join(path, "priv/static/js/phoenix.js"), phoenix_js_text()
      create_file Path.join(path, "priv/static/images/phoenix.png"), phoenix_png_text()
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

  defp install_brunch(_binding) do
    # Check for npm executable because if it is not
    # available we have already asked a question before
    if File.exists?("brunch-config.js") && System.find_executable("npm") do
      ask_and_run("Install brunch.io dependencies?", "npm", "install")
    end
  end

  defp install_mix(_) do
    ask_and_run("Install mix dependencies?", "mix", "deps.get")
  end

  ## Helpers

  defp ask_and_run(question, command, args) do
    if System.find_executable(command) && Mix.shell.yes?("\n" <> question) do
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
