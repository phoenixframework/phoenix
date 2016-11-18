defmodule Mix.Tasks.Phx.New.Project do
  alias Mix.Tasks.Phx.New.Project

  defstruct base_path: nil,
            app: nil,
            app_mod: nil,
            app_path: nil,
            root_app: nil,
            root_mod: nil,
            project_path: nil,
            web_app: nil,
            web_namespace: nil,
            web_path: nil,
            binding: []

  def new(base_path) do
    %Project{base_path: base_path}
  end

  def ecto?(%Project{binding: binding} = project) do
    binding[:ecto]
  end

  def html?(%Project{binding: binding} = project) do
    binding[:html]
  end

  def brunch?(%Project{binding: binding} = project) do
    binding[:brunch]
  end
end
