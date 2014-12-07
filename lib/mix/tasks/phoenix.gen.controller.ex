defmodule Mix.Tasks.Phoenix.Gen.Controller do
  use Mix.Task
  alias Phoenix.Naming
  import Mix.Phoenix

  @shortdoc "Creates Phoenix controller"

  @moduledoc """
  Creates a new Phoenix controller, empty view file, empty template dir and empty test for the generated controller.

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

    copy_from template_dir, "./", {"controller_name", controller_name}, &EEx.eval_file(&1, binding)
    Mix.shell.info """
    Don't forget to add your new controller to your web/router.ex

        resources "/#{controller}", #{controller_name}Controller
    
    """
  end

  def run(_, _opts) do
    Mix.raise """
    phoenix.gen.controller expects a controller name

        mix phoenix.gen.controller controller_name

    """
  end

  defp template_dir do
    Application.app_dir(:phoenix, "priv/templates/controller")
  end
end
