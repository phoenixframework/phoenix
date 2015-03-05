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

  An `--app` option can be given in order to
  name the OTP application for the project.

  A `--module` option can be given in order
  to name the modules in the generated code skeleton.

  By default, Brunch is added for static asset building and nodejs
  deps are automatically installed via npm.
  To skip brunch related files, use the  `--skip-brunch` option.
  To setup brunch, but skip npm install, use the `--skip-npm` option.

  ## Examples

      mix phoenix.new hello_world

  Is equivalent to:

      mix phoenix.new hello_world --module HelloWorld

  Without brunch:

      mix phoenix.new ~/Workspace/hello_world --skip-brunch

  """

  def run(argv) do
    {opts, argv, _} = OptionParser.parse(argv, switches: [dev: :boolean])

    case argv do
      [] ->
        Mix.raise "Expected PATH to be given, please use `mix phoenix.new PATH`"
      [path|_] ->
        app    = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !!opts[:app])
        mod = opts[:module] || Naming.camelize(app)
        check_mod_name!(mod)

        run(app, mod, path, opts[:dev], opts[:skip_brunch], opts[:skip_npm])
    end
  end

  def run(app, mod, path, dev, skip_brunch, skip_npm) do
    pubsub_server = mod
                    |> Module.concat(nil)
                    |> Naming.base_concat(PubSub)
    npm_path = System.find_executable("npm")
    binding = [application_name: app,
               application_module: mod,
               phoenix_dep: phoenix_dep(dev),
               pubsub_server: pubsub_server,
               secret_key_base: random_string(64),
               encryption_salt: random_string(8),
               signing_salt: random_string(8),
               in_umbrella: in_umbrella?(path)]

    copy_from template_dir(), path, app, &EEx.eval_file(&1, binding)

    cond do
      !skip_brunch && !skip_npm && npm_path ->
        setup_brunch_files(app, path)
        IO.puts "Installing brunch.io dependencies..."
        IO.puts "npm install --prefix #{path}"
        if Mix.env == :dev, do: System.cmd("npm", ["install", "--prefix", path])

      !skip_brunch && (skip_npm || !npm_path)->
        setup_brunch_files(app, path)
        IO.puts """

        Brunch was setup for static assets, but node deps were not installed via npm.
        Installation instructions for nodejs, which includes npm, can be found
        at http://nodejs.org

        You can install your brunch dependencies by running:

            $ cd #{path}
            $ npm install

        """

      true ->
        File.rm_rf!(Path.join(path, "web/static"))
        File.rm!(Path.join(path, "brunch-config.js"))
        File.rm!(Path.join(path, "package.json"))
        copy_from static_dir(), Path.join(path, "priv/static"), app, &File.read!(&1)
    end
  end

  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
  end

  defp setup_brunch_files(app, path) do
    path
    |> Path.join(".gitignore")
    |> File.open([:append], &IO.puts(&1, "/node_modules"))

    File.cp!(Path.join(static_dir(), "phoenix.js"), Path.join(path, "web/static/vendor/phoenix.js"))
    File.cp!(Path.join(static_dir(), "app.css"), Path.join(path, "web/static/css/app.scss"))
    copy_from Path.join(static_dir(), "images"),
              Path.join(path, "web/static/assets/images"),
              app,
              &File.read!(&1)
  end

  defp copy_from(source_dir, target_dir, application_name, fun) do
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
          contents = fun.(source_path)
          Mix.Generator.create_file(target_path, contents)
      end
    end

    :ok
  end

  defp check_application_name!(name, from_app_flag) do
    unless name =~ ~r/^[a-z][\w_]*$/ do
      Mix.raise "Application name must start with a letter and have only lowercase " <>
                "letters, numbers and underscore, got: #{inspect name}" <>
                (if !from_app_flag do
                  ". The application name is inferred from the path, if you'd like to " <>
                  "explicitly name the application then use the `--app APP` option."
                else
                  ""
                end)
    end
  end

  defp check_mod_name!(name) do
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

  defp make_destination_path(source_path, source_dir, target_dir, application_name) do
    target_path =
      source_path
      |> String.replace("application_name", application_name)
      |> Path.relative_to(source_dir)
    Path.join(target_dir, target_path)
  end

  defp phoenix_dep(true), do: ~s[{:phoenix, path: #{inspect File.cwd!}}]
  defp phoenix_dep(_),    do: ~s[{:phoenix, github: "phoenixframework/phoenix"}]

  defp template_dir do
    Application.app_dir(:phoenix, "priv/template")
  end

  defp static_dir do
    Application.app_dir(:phoenix, "priv/static")
  end
end
