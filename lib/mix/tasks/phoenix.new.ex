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

    * `--no-brunch` - do not generate brunch file
      for static asset building

  ## Examples

      mix phoenix.new hello_world

  Is equivalent to:

      mix phoenix.new hello_world --module HelloWorld

  Without brunch:

      mix phoenix.new ~/Workspace/hello_world --no-brunch

  """

  @brunch %{
    "brunch/.gitignore"       => ".gitignore",
    "brunch/brunch-config.js" => "brunch-config.js",
    "brunch/package.json"     => "package.json",
    "brunch/app.js"           => "web/static/js/app.js",
    "phoenix.js"              => "web/static/vendor/phoenix.js",
    "app.css"                 => "web/static/css/app.scss",
    "images/phoenix.png"      => "web/static/assets/images/phoenix.png"
  }

  @bare %{
    "bare/.gitignore"         => ".gitignore",
    "bare/app.js"             => "priv/static/js/app.js",
    "phoenix.js"              => "priv/static/js/phoenix.js",
    "app.css"                 => "priv/static/css/app.css",
    "images/phoenix.png"      => "priv/static/images/phoenix.png"
  }

  @switches [dev: :boolean, brunch: :boolean]

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
    brunch = Keyword.get(opts, :brunch, true)

    pubsub_server = [mod]
                    |> Module.concat()
                    |> Naming.base_concat(PubSub)

    binding = [application_name: app,
               application_module: mod,
               phoenix_dep: phoenix_dep(dev),
               pubsub_server: pubsub_server,
               secret_key_base: random_string(64),
               encryption_salt: random_string(8),
               signing_salt: random_string(8),
               in_umbrella: in_umbrella?(path),
               brunch: brunch]

    copy_from template_dir(), path, app, &EEx.eval_file(&1, binding)

    # Optional contents
    copy_static path, binding
    # copy_model path, binding

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

  defp copy_static(path, binding) do
    if binding[:brunch] do
      copy_from static_dir(), path, @brunch
    else
      copy_from static_dir(), path, @bare
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
           ask_and_run("Install brunch.io dependencies?", "npm", ["install"])

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
    ask_and_run("Install mix dependencies?", "mix", ["deps.get"])
  end

  ## Copying functions

  defp copy_from(source_dir, target_dir, file_map) when is_map(file_map) do
    for {source_file_path, target_file_path} <- file_map do
      source = Path.join(source_dir, source_file_path)
      target = Path.join(target_dir, target_file_path)
      Mix.Generator.create_file(target, File.read!(source))
    end
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

  defp make_destination_path(source_path, source_dir, target_dir, application_name) do
    target_path =
      source_path
      |> String.replace("application_name", application_name)
      |> Path.relative_to(source_dir)
    Path.join(target_dir, target_path)
  end

  ## Helpers

  defp ask_and_run(question, command, args) do
    if System.find_executable(command) &&
       Mix.shell.yes?("\n" <> question) do

      Mix.shell.info [:green, "* running ", :reset, Enum.join([command|args], " ")]
      Task.async(fn -> System.cmd(command, args) end)
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

  defp phoenix_dep(true), do: ~s[{:phoenix, path: #{inspect File.cwd!}}]
  defp phoenix_dep(_),    do: ~s[{:phoenix, github: "phoenixframework/phoenix"}]

  defp random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
  end

  defp template_dir do
    Application.app_dir(:phoenix, "priv/template")
  end

  defp static_dir do
    Application.app_dir(:phoenix, "priv/static")
  end
end
