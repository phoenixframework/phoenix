defmodule Mix.Tasks.Phoenix.New do
  use Mix.Task
  alias Phoenix.Naming

  @shortdoc "Creates Phoenix application"

  @moduledoc """
  Creates a new Phoenix application

      mix phoenix.new app_name path

  """

  def run(args) do
    {opts, args, _} = OptionParser.parse(args, strict: [dev: :boolean])
    run(args, opts)
  end

  def run([name, path], opts) do
    application_name   = Naming.underscore(name)
    application_module = Naming.camelize(application_name)

    binding = [application_name: application_name,
               application_module: application_module,
               phoenix_dep: phoenix_dep(opts[:dev]),
               secret_key_base: random_string(64),
               encryption_salt: random_string(8),
               signing_salt: random_string(8)]

    copy_from template_dir, path, application_name, &EEx.eval_file(&1, binding)
    copy_from static_dir, Path.join(path, "priv/static"), application_name, &File.read!(&1)
  end

  def run(_, _opts) do
    Mix.raise """
    phoenix.new expects application name and destination path.

        mix phoenix.new my_app /home/johndoe/my_app

    """
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

      unless File.dir?(source_path) do
        contents = fun.(source_path)
        Mix.Generator.create_file(target_path, contents)
      end
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
  defp phoenix_dep(_),    do: ~s[{:phoenix, "~> 0.7.2"}]

  defp template_dir do
    Application.app_dir(:phoenix, "priv/template")
  end

  defp static_dir do
    Application.app_dir(:phoenix, "priv/static")
  end
end
