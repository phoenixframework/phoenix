defmodule Phx.New.Oban do
  @moduledoc false

  use Phx.New.Generator

  alias Phx.New.Project

  template(:new, [
    {:eex, :app, "phx_oban/lib/app_name/oban.ex": "lib/:app/oban.ex"}
  ])

  def prepare_project(%Project{} = project) do
    app_path = Path.expand(project.base_path)
    project_path = Path.dirname(Path.dirname(app_path))

    %Project{project | in_umbrella?: true, app_path: app_path, project_path: project_path}
  end

  def generate(%Project{} = project) do
    inject_umbrella_config_defaults(project)
    copy_from(project, __MODULE__, :new)
    project
  end
end
