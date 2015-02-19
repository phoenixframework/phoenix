defmodule Mix.Tasks.Phoenix.New do
  use Mix.Task
  alias Phoenix.Naming

  @shortdoc "Creates Phoenix application"

  @moduledoc """
  Creates a new Phoenix project.
  It expects the path of the project as argument.

      mix phoenix.new PATH [--module MODULE] [--app APP]

  A project at the given PATH  will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.

  """

  def run(argv) do
    {opts, argv, _} = OptionParser.parse(argv, switches: [dev: :boolean])

    case argv do
      [] ->
        Mix.raise "Expected PATH to be given, please use `mix phoenix.new PATH`"
      [path|_] ->
        app    = opts[:app] || Path.basename(Path.expand(path))
        module = opts[:module] || Naming.camelize(app)

        run(app, module, path, opts[:dev])
    end
  end


  def run(app, module, path, dev) do
    pubsub_server      = module
                         |> Module.concat(nil)
                         |> Naming.base_concat(PubSub)
    binding = [application_name: app,
               application_module: module,
               phoenix_dep: phoenix_dep(dev),
               pubsub_server: pubsub_server,
               secret_key_base: random_string(64),
               encryption_salt: random_string(8),
               signing_salt: random_string(8)]

    copy_from template_dir, path, app, &EEx.eval_file(&1, binding)
    copy_from static_dir, Path.join(path, "priv/static"), app, &File.read!(&1)
  end

  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
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

  defp phoenix_dep(true), do: ~s[{:phoenix, path: #{inspect File.cwd!}}]
  defp phoenix_dep(_),    do: ~s[{:phoenix, github: "phoenixframework/phoenix"}]

  defp template_dir do
    Application.app_dir(:phoenix, "priv/template")
  end

  defp static_dir do
    Application.app_dir(:phoenix, "priv/static")
  end
end
