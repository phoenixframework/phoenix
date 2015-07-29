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

    attrs   = Mix.Phoenix.attrs(attrs)
    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]
    route   = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")
    binding = binding ++ [plural: plural, route: route, attrs: attrs,
                          inputs: inputs(attrs), params: Mix.Phoenix.params(attrs)]

    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "Controller")
    Mix.Phoenix.check_module_name_availability!(binding[:module] <> "View")

    if opts[:model] != false do
      Mix.Task.run "phoenix.gen.model", args
    end

    Mix.Phoenix.copy_from apps(), "priv/templates/phoenix.gen.html", "", binding, [
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

    Add the resource to your browser scope in web/router.ex:

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
      {_k, {:array, _}} ->
        {nil, nil}
      {k, :belongs_to} ->
        {~s(<%= number_input f, #{inspect(k)}_id, class: "form-control" %>), label(k, :belongs_to)}
      {k, :integer}    ->
        {~s(<%= number_input f, #{inspect(k)}, class: "form-control" %>), label(k)}
      {k, :float}      ->
        {~s(<%= number_input f, #{inspect(k)}, step: "any", class: "form-control" %>), label(k)}
      {k, :decimal}    ->
        {~s(<%= number_input f, #{inspect(k)}, step: "any", class: "form-control" %>), label(k)}
      {k, :boolean}    ->
        {~s(<%= checkbox f, #{inspect(k)}, class: "form-control" %>), label(k)}
      {k, :text}       ->
        {~s(<%= textarea f, #{inspect(k)}, class: "form-control" %>), label(k)}
      {k, :date}       ->
        {~s(<%= date_select f, #{inspect(k)}, class: "form-control" %>), label(k)}
      {k, :time}       ->
        {~s(<%= time_select f, #{inspect(k)}, class: "form-control" %>), label(k)}
      {k, :datetime}   ->
        {~s(<%= datetime_select f, #{inspect(k)}, class: "form-control" %>), label(k)}
      {k, _}           ->
        {~s(<%= text_input f, #{inspect(k)}, class: "form-control" %>), label(k)}
    end
  end

  defp label(key) do
    label_text = Phoenix.Naming.humanize(key)
    ~s(<%= label f, #{inspect(key)}, "#{label_text}" %>)
  end
  defp label(key, :belongs_to) do
    label_text = Phoenix.Naming.humanize(Atom.to_string(key) <> "_id")
    ~s(<%= label f, #{inspect(key)}_id, "#{label_text}" %>)
  end

  defp apps do
    [Mix.Project.config[:app], :phoenix]
  end
end
