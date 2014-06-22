defmodule Phoenix.View do
  alias Phoenix.Project

  defmacro __using__(options \\ []) do
    create_missing_views = Dict.get(options, :create_missing_views, false)
    templates_root = Dict.fetch!(options, :templates_root)

    quote do
      import unquote(__MODULE__)
      path = template_path_from_module(__MODULE__, unquote(templates_root))
      use Phoenix.Template.Compiler, path: path
      if unquote(create_missing_views) do
        @after_compile Phoenix.View.AutoCreator
      end
    end
  end

  def safe({:safe, string}), do: {:safe, string}
  def safe(string), do: {:safe, string}

  def unsafe({:unsafe, string}), do: {:unsafe, string}
  def unsafe(string), do: {:unsafe, string}

  @doc """
  Finds the template path given view module and template root path

  Examples

  iex> View.template_path_from_module(MyApp.Views.Users, "my_app/lib/templates")
  "my_app/lib/templates/users"
  """
  def template_path_from_module(view_module, templates_root) do
    names       = Module.split(view_module)
    views_index = Enum.find_index(names, &(&1 == "Views"))
    submodules  = Enum.split(names, views_index) |> elem(1) |> tl
    submodule_path = submodules |> Enum.map(&Mix.Utils.underscore/1) |> Path.join

    Path.join(templates_root, submodule_path)
  end
end

