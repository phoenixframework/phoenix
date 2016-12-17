defmodule Phx.New.Umbrella do
  use Phx.New.Generator
  alias Mix.Tasks.Phx.New.{App, Web}
  alias Phx.New.{Project}

  template :new, [
    {:eex,  "phx_umbrella/config/config.exs", :project, "config/config.exs"},
    {:eex,  "phx_umbrella/mix.exs",           :project, "mix.exs"},
    {:eex,  "phx_umbrella/README.md",         :project, "README.md"},
  ]

  def prepare_project(%Project{app: app} = project) when not is_nil(app) do
    project
    |> App.prepare_project()
    |> Web.prepare_project()
    |> put_root_app()
  end

  defp put_root_app(%Project{app: app} = project) do
    %Project{project |
             root_app: :"#{app}_umbrella",
             root_mod: Module.concat(project.app_mod, Umbrella)}
  end

  def generate(%Project{} = project) do
    if in_umbrella?(project.project_path) do
      Mix.raise "unable to nest umbrella project within apps"
    end
    copy_from project, __MODULE__, template_files(:new)

    project
    |> Web.generate()
    |> App.generate()
  end
end
