defmodule Mix.Tasks.Phoenix.Gen.Html do
  use Mix.Task

  import String, only: [to_atom: 1]

  @shortdoc "Generates HTML files for a resource"

  @moduledoc """
  Generates a Phoenix resource.

      mix phoenix.gen.html User users name:string age:integer

  The first argument is the module name followed by
  its plural name (used for resources and schema).

  The generated resource will contain:

    * a model in web/models
    * a view in web/views
    * a controller in web/controllers
    * a migration file for the repository
    * default CRUD templates in web/templates

  Read the documentation for `phoenix.gen.model` for more
  information on attributes and namespaced resources.
  """
  def run([singular, plural|attrs] = args) do
    if String.contains?(plural, ":"), do: raise_with_help
    Mix.Task.run "phoenix.gen.model", args

    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]
    route   = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")
    binding = binding ++ [plural: plural, route: route, inputs: inputs(attrs), sample_params: sample_params(attrs)]

    Mix.Phoenix.copy_from source_dir, "", binding, [
      {:eex, "controller.ex",  "web/controllers/#{path}_controller.ex"},
      {:eex, "controller_test.exs",  "test/controllers/#{path}_controller_test.exs"},
      {:eex, "edit.html.eex",  "web/templates/#{path}/edit.html.eex"},
      {:eex, "form.html.eex",  "web/templates/#{path}/form.html.eex"},
      {:eex, "index.html.eex", "web/templates/#{path}/index.html.eex"},
      {:eex, "new.html.eex",   "web/templates/#{path}/new.html.eex"},
      {:eex, "show.html.eex",  "web/templates/#{path}/show.html.eex"},
      {:eex, "view.ex",        "web/views/#{path}_view.ex"},
    ]

    Mix.shell.info """

    Add the resource to the proper scope in web/router.ex:

        resources "/#{route}", #{binding[:scoped]}Controller

    and then update your repository by running migrations:

        $ mix ecto.migrate
    """
  end

  def run(_) do
    raise_with_help
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.gen.html expects both singular and plural names
    of the generated resource followed by any number of attributes:

        mix phoenix.gen.html User users name:string
    """
  end

  defp inputs(attrs) do
    Enum.map attrs, fn attr ->
      {k, v} =
        case String.split(attr, ":", parts: 3) do
          [k, _, _]       -> {k, nil}
          [k, "integer"]  -> {k, "number_input f, #{to_atom(k) |> inspect}"}
          [k, "float"]    -> {k, "number_input f, #{to_atom(k) |> inspect}, step: \"any\""}
          [k, "decimal"]  -> {k, "number_input f, #{to_atom(k) |> inspect}, step: \"any\""}
          [k, "boolean"]  -> {k, "checkbox f, #{to_atom(k) |> inspect}"}
          [k, "text"]     -> {k, "textarea f, #{to_atom(k) |> inspect}"}
          [k, "date"]     -> {k, "date_select f, #{to_atom(k) |> inspect}"}
          [k, "time"]     -> {k, "time_select f, #{to_atom(k) |> inspect}"}
          [k, "datetime"] -> {k, "datetime_select f, #{to_atom(k) |> inspect}"}
          [k, _]          -> {k, "text_input f, #{to_atom(k) |> inspect}"}
          [k]             -> {k, "text_input f, #{to_atom(k) |> inspect}"}
        end
      {to_atom(k), v}
    end
  end

  defp sample_params(attrs) do
    sample_params = Enum.map attrs, fn attr ->
      {k, v} =
        case String.split(attr, ":", parts: 3) do
          [k, _, _]       -> {k, []}
          [k, "integer"]  -> {k, 42}
          [k, "float"]    -> {k, "120.5"}
          [k, "decimal"]  -> {k, "120.5"}
          [k, "boolean"]  -> {k, true}
          [k, "text"]     -> {k, "a binary"}
          [k, "date"]     -> {k, "a binary"}
          [k, "time"]     -> {k, "a binary"}
          [k, "datetime"]  -> {k, [year: 2014, month: 12, day: 1, hour: 12, min: 1]}
          [k, "uuid"]     -> {k, "7488a646-e31f-11e4-aace-600308960662"}
          [k, _]          -> {k, "a binary"}
          [k]             -> {k, "a binary"}
        end
      {to_atom(k), v}
    end

    inspect(sample_params)
  end

  defp source_dir do
    Application.app_dir(:phoenix, "priv/templates/resource")
  end
end
