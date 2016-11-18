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

    * `--no-ecto` - do not generate ecto files.

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

    case parse_opts(argv) do
      {_opts, []}             -> Mix.Tasks.Help.run ["phx.new"]
      {opts, [base_path | _]} -> generate(base_path, opts)
    end
  end

  defp generate(base_path, opts) do
    generator = if opts[:umbrella], do: Umbrella, else: Single

    base_path
    |> Project.new()
    |> generator.put_app(opts)
    |> generator.put_root_app()
    |> generator.put_web_app()
    |> Generator.put_binding(generator, opts)
    |> validate_project(opts)
    |> generator.gen_new()
    |> prompt_to_install_deps()
  end

  defp validate_project(%Project{} = project, opts) do
    check_app_name!(project.app, !!opts[:app])
    check_directory_existence!(project.project_path)
    check_module_name_validity!(project.root_mod)
    check_module_name_availability!(project.root_mod)

    project
  end

  defp prompt_to_install_deps(%Project{} = project) do
    install? = Mix.shell.yes?("\nFetch and install dependencies?")

    File.cd!(project.project_path, fn ->
      mix? = install_mix(install?)
      File.cd!(project.web_path, fn ->
        brunch? = install_brunch(install?)
        extra   = if mix?, do: [], else: ["$ mix deps.get"]

        print_mix_info(project.project_path, extra)

        if Project.ecto?(project), do: print_ecto_info()

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

        $ cd assets && npm install

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
    [name]
    |> Module.concat()
    |> Module.split()
    |> Enum.reduce([], fn name, acc ->
        mod = Module.concat([Elixir, name | acc])
        if Code.ensure_loaded?(mod) do
          Mix.raise "Module name #{inspect mod} is already taken, please choose another name"
        else
          [name | acc]
        end
    end)
  end

  defp check_directory_existence!(path) do
    if File.dir?(path) and not Mix.shell.yes?("The directory #{path} already exists. Are you sure you want to continue?") do
      Mix.raise "Please select another directory for installation."
    end
  end
end
