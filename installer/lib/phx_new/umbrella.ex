defmodule Mix.Tasks.Phx.New.Umbrella do
  use Phx.New.Generator
  alias Phx.New.{Project, Generator}

  template :new, [
    {:eex,  "phx_umbrella/config/config.exs", "config/config.exs"},
    {:eex,  "phx_umbrella/mix.exs",           "mix.exs"},
    {:eex,  "phx_umbrella/README.md",         "README.md"},
  ]


  def put_app(%Project{base_path: base_path, opts: opts} = project) do
    app = opts[:app] || Path.basename(Path.expand(base_path))
    app_path = Path.join(base_path <> "_umbrella", "apps/#{app}")

    %Project{project |
             app: app,
             app_mod: Module.concat([opts[:module] || Macro.camelize(app)]),
             app_path: app_path,
             project_path: Path.expand(base_path)}
  end

  def put_root_app(%Project{app: app} = project) when not is_nil(app) do
    %Project{project |
             root_app: :"#{app}_umbrella",
             root_mod: Module.concat(project.app_mod, Umbrella)}
  end

  def put_web_app(%Project{app: app} = project) when not is_nil(app) do
    web_app = :"#{app}_web"

    %Project{project |
             web_app: web_app,
             web_namespace: Module.concat(project.app_mod, Web),
             web_path: Path.join(project.project_path, "apps/#{web_app}/")}
  end

  def generate(%Project{} = project) do
    if in_umbrella?(project.project_path) do
      Mix.raise "unable to nest umbrella project within apps"
    end
    copy_from project.project_path, __MODULE__, project.binding, template_files(:new)

    Generator.Web.generate(project)
    Generator.App.generate(project)
  end
end
