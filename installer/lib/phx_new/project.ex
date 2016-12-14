defmodule Phx.New.Project do
  alias Phx.New.Project

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
            opts: :unset,
            binding: []

  def new(base_path, opts) do
    %Project{base_path: base_path, opts: opts}
  end

  def ecto?(%Project{binding: binding}) do
    Keyword.fetch!(binding, :ecto)
  end

  def html?(%Project{binding: binding}) do
    Keyword.fetch!(binding, :html)
  end

  def brunch?(%Project{binding: binding}) do
    Keyword.fetch!(binding, :brunch)
  end
end
