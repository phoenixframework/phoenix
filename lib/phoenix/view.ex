defmodule Phoenix.View do

  defmacro __using__(options \\ []) do
    templates_root = Dict.fetch!(options, :templates_root)

    quote do
      import unquote(__MODULE__)
      import Phoenix.Html, only: [safe: 1, unsafe: 1]
      path = template_path_from_view_module(__MODULE__, unquote(templates_root))
      use Phoenix.Template.Compiler, path: path
    end
  end

  @doc """
  Finds the template path given view module and template root path

  Examples

  iex> View.template_path_from_view_module(MyApp.UserView, "web/templates")
  "web/templates/user"
  """
  def template_path_from_view_module(view_module, templates_root) do
    submodule_path = view_module
    |> Module.split
    |> tl
    |> Enum.map(&Mix.Utils.underscore/1)
    |> Path.join
    |> String.replace(~r/^(.*)(_view)$/, "\\1")

    Path.join(templates_root, submodule_path)
  end
end

