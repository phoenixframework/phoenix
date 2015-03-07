defmodule Mix.Tasks.Phoenix.Gen.Resource do
  use Mix.Task
  alias Phoenix.Naming

  @shortdoc "Generates resource files"

  @moduledoc """
  Generates a Phoenix resource.

      mix phoenix.gen.resource User users name:string age:integer

  The first argument is the module name followed by
  its plural name (used for resources and schema).

  The generated resource will contain:

    * a model in web/models
    * a view in web/views
    * a controller in web/controllers
    * a migration file for the repository
    * default CRUD templates in web/templates

  ## Namespaced resources

  Resources can be namespaced, for such, it is just necessary
  to namespace the first argument of the generator:

      mix phoenix.gen.resource Admin.User admin_users name:string age:integer

  """
  def run([singular, plural|attrs]) do
    base     = Mix.Phoenix.base
    camelize = Naming.camelize(singular)
    path     = Naming.underscore(camelize)
    singular = String.split(path, "/") |> List.last
    module   = Module.concat(base, camelize) |> inspect
    alias    = Module.split(module) |> List.last
    route    = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")
    attrs    = split_attrs(attrs)

    binding = [path: path, singular: singular, module: module, attrs: attrs,
               plural: plural, route: route, base: base, alias: alias,
               types: types(attrs), inputs: inputs(attrs), defaults: defaults(attrs)]

    Mix.Phoenix.copy_from source_dir, "", binding, [
      {:eex, "controller.ex",  "web/controllers/#{path}_controller.ex"},
      {:eex, "model.ex",       "web/models/#{path}.ex"},
      {:eex, "view.ex",        "web/views/#{path}_view.ex"},
      {:eex, "index.html.eex", "web/templates/#{path}/index.html.eex"},
      {:eex, "edit.html.eex",  "web/templates/#{path}/edit.html.eex"},
      {:eex, "form.html.eex",  "web/templates/#{path}/form.html.eex"},
      {:eex, "new.html.eex",   "web/templates/#{path}/new.html.eex"},
      {:eex, "show.html.eex",  "web/templates/#{path}/show.html.eex"},
    ]

    Mix.shell.info """

    Add the resource to the proper scope in web/router.ex:

        resources "/#{route}", #{camelize}Controller

    and then update your repository by running migrations:

        $ mix ecto.migrate
    """
  end

  def run(_) do
    Mix.raise """
    mix phoenix.gen.resource expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.resource User users name:string
    """
  end

  defp split_attrs(attrs) do
    Enum.map attrs, fn attr ->
      case String.split(attr, ":", parts: 2) do
        [key, value] -> {String.to_atom(key), String.to_atom(value)}
        [key]        -> {String.to_atom(key), :string}
      end
    end
  end

  defp types(attrs) do
    Enum.into attrs, %{}, fn
      {k, :uuid}     -> {k, Ecto.UUID}
      {k, :date}     -> {k, Ecto.Date}
      {k, :time}     -> {k, Ecto.Time}
      {k, :datetime} -> {k, Ecto.DateTime}
      {k, v}         -> {k, v}
    end
  end

  defp inputs(attrs) do
    Enum.into attrs, %{}, fn
      {k, :integer}  -> {k, :number_input}
      {k, :float}    -> {k, :number_input}
      {k, :decimal}  -> {k, :number_input}
      {k, :boolean}  -> {k, :checkbox}
      {k, :date}     -> {k, :date_select}
      {k, :time}     -> {k, :time_select}
      {k, :datetime} -> {k, :datetime_select}
      {k, _}         -> {k, :text_input}
    end
  end

  defp defaults(attrs) do
    Enum.into attrs, %{}, fn
      {k, :boolean}  -> {k, ", default: false"}
      {k, _}         -> {k, ""}
    end
  end

  defp source_dir do
    Application.app_dir(:phoenix, "priv/templates/resource")
  end
end