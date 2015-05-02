defmodule Mix.Tasks.Phoenix.Gen.Html do
  use Mix.Task

  @shortdoc "Generates controller, model and views for an HTML-based resource"

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
    * test files for generated model and controller

  The generated model can be skipped with `--no-model`.
  Read the documentation for `phoenix.gen.model` for more
  information on attributes and namespaced resources.
  """
  def run(args) do
    {opts, parsed, _} = OptionParser.parse(args, switches: [model: :boolean])
    [singular, plural | attrs] = validate_args!(parsed)

    if opts[:model] != false do
      Mix.Task.run "phoenix.gen.model", args
    end

    attrs   = Mix.Phoenix.attrs(attrs)
    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]
    route   = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")
    binding = binding ++ [plural: plural, route: route,
                          inputs: inputs(attrs), params: Mix.Phoenix.params(attrs)]

    Mix.Phoenix.copy_from source_dir, "", binding, [
      {:eex, "controller.ex",       "web/controllers/#{path}_controller.ex"},
      {:eex, "edit.html.eex",       "web/templates/#{path}/edit.html.eex"},
      {:eex, "form.html.eex",       "web/templates/#{path}/form.html.eex"},
      {:eex, "index.html.eex",      "web/templates/#{path}/index.html.eex"},
      {:eex, "new.html.eex",        "web/templates/#{path}/new.html.eex"},
      {:eex, "show.html.eex",       "web/templates/#{path}/show.html.eex"},
      {:eex, "view.ex",             "web/views/#{path}_view.ex"},
      {:eex, "controller_test.exs", "test/controllers/#{path}_controller_test.exs"},
    ]

    Mix.shell.info """

    Add the resource to the proper scope in web/router.ex:

        resources "/#{route}", #{binding[:scoped]}Controller
    """

    if opts[:model] != false do
      Mix.shell.info """
      and then update your repository by running migrations:

          $ mix ecto.migrate
      """
    end
  end

  defp validate_args!([_, plural | _] = args) do
    if String.contains?(plural, ":") do
      raise_with_help
    else
      args
    end
  end

  defp validate_args!(_) do
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
    Enum.map attrs, fn
      {k, {:array, _}} -> {k, nil}
      {k, :belongs_to} -> {k, "number_input f, #{inspect(k)}_id"}
      {k, :integer}    -> {k, "number_input f, #{inspect(k)}"}
      {k, :float}      -> {k, "number_input f, #{inspect(k)}, step: \"any\""}
      {k, :decimal}    -> {k, "number_input f, #{inspect(k)}, step: \"any\""}
      {k, :boolean}    -> {k, "checkbox f, #{inspect(k)}"}
      {k, :text}       -> {k, "textarea f, #{inspect(k)}"}
      {k, :date}       -> {k, "date_select f, #{inspect(k)}"}
      {k, :time}       -> {k, "time_select f, #{inspect(k)}"}
      {k, :datetime}   -> {k, "datetime_select f, #{inspect(k)}"}
      {k, _}           -> {k, "text_input f, #{inspect(k)}"}
    end
  end

  defp source_dir do
    Application.app_dir(:phoenix, "priv/templates/html")
  end
end
