defmodule Mix.Tasks.Phoenix.New do
  use Mix.Task
  alias Phoenix.Naming
  import Mix.Phoenix

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
               secret_key_base: random_string(64)]

    copy_from template_dir, path, application_name, &EEx.eval_file(&1, binding)
    copy_from static_dir, Path.join(path, "priv/static"), {"application_name", application_name}, &File.read!(&1)
  end

  def run(_, _opts) do
    Mix.raise """
    phoenix.new expects application name and destination path.

        mix phoenix.new my_app /home/johndoe/my_app

    """
  end

  def random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64
  end

  defp phoenix_dep(true), do: ~s[{:phoenix, path: #{inspect File.cwd!}}]
  defp phoenix_dep(_),    do: ~s[{:phoenix, github: "phoenixframework/phoenix"}]

  defp template_dir do
    Application.app_dir(:phoenix, "priv/templates/app")
  end

  defp static_dir do
    Application.app_dir(:phoenix, "priv/static")
  end
end
