defmodule Mix.Tasks.Phoenix.Gen.Controller do
  use Mix.Task
  alias Phoenix.Naming

  @shortdoc "Creates Phoenix controller"

  @moduledoc """
  Creates a new Phoenix application

      mix phoenix.gen.controller controller_name

  """

  def run(args) do
    run(args, nil)
  end

  def run([name], _opts) do
    application_name   = Naming.camelize(Mix.Project.config()[:app])
    controller = name
    controller_name = Naming.camelize(controller)

    binding = [application_name: application_name,
               controller: controller,
               controller_name: controller_name]

    copy_from template_dir, "./", controller_name, &EEx.eval_file(&1, binding)
    Mix.shell.info """
    Don't forget to add your new controller to your web/router.ex

        resource "/#{controller}", #{application_name}.#{controller_name}Controller
    
    """
  end

  def run(_, _opts) do
    Mix.raise """
    phoenix.gen.controller expects a controller name

        mix phoenix.gen.controller controller_name

    """
  end

  defp copy_from(source_dir, target_dir, controller_name, fun) do
    source_paths =
      source_dir
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)
    controller_name = String.downcase(controller_name)

    for source_path <- source_paths do
      target_path = make_destination_path(source_path, source_dir,
                                          target_dir, controller_name)

      unless File.dir?(source_path) do
        contents = fun.(source_path)
        Mix.Generator.create_file(target_path, contents)
      end
    end
  end

  defp make_destination_path(source_path, source_dir, target_dir, controller_name) do
    target_path =
      source_path
      |> String.replace("controller_name", controller_name)
      |> Path.relative_to(source_dir)
    Path.join(target_dir, target_path)
  end

  defp template_dir do
    Application.app_dir(:phoenix, "priv/templates/controller")
  end
end
