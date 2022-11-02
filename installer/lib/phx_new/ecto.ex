defmodule Phx.New.Ecto do
  @moduledoc false
  use Phx.New.Generator
  alias Phx.New.{Project}

  @pre "phx_umbrella/apps/app_name"

  template(:new, [
    {:config, :project, "#{@pre}/config/config.exs": "config/config.exs"},
    {:eex, :app,
     "#{@pre}/lib/app_name/application.ex": "lib/:app/application.ex",
     "#{@pre}/lib/app_name.ex": "lib/:app.ex",
     "#{@pre}/test/test_helper.exs": "test/test_helper.exs",
     "#{@pre}/README.md": "README.md",
     "#{@pre}/mix.exs": "mix.exs",
     "#{@pre}/gitignore": ".gitignore",
     "#{@pre}/formatter.exs": ".formatter.exs"}
  ])

  def prepare_project(%Project{} = project) do
    app_path = Path.expand(project.base_path)
    project_path = Path.dirname(Path.dirname(app_path))

    %Project{project | in_umbrella?: true, app_path: app_path, project_path: project_path}
  end

  def generate(%Project{} = project) do
    inject_umbrella_config_defaults(project)
    copy_from(project, __MODULE__, :new)
    if Project.ecto?(project), do: Phx.New.Single.gen_ecto(project)
    project
  end
end
