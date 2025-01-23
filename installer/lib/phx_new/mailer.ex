defmodule Phx.New.Mailer do
  @moduledoc false
  use Phx.New.Generator
  alias Phx.New.{Project}

  template(:new, [
    {:eex, :app, "phx_mailer/lib/app_name/mailer.ex": "lib/:app/mailer.ex"}
  ])

  def prepare_project(%Project{} = project) do
    app_path = Path.expand(project.base_path)
    project_path = Path.dirname(Path.dirname(app_path))

    %{project | in_umbrella?: true, app_path: app_path, project_path: project_path}
  end

  def generate(%Project{} = project) do
    inject_umbrella_config_defaults(project)
    copy_from(project, __MODULE__, :new)
    project
  end
end
