defmodule Phoenix.View do

  defmacro __using__(options \\ []) do
    templates_root = Dict.fetch!(options, :templates_root)

    quote do
      import unquote(__MODULE__)
      import Phoenix.Html, only: [safe: 1, unsafe: 1]
      path = template_path_from_module(__MODULE__, unquote(templates_root))
      use Phoenix.Template.Compiler, path: path
    end
  end

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

