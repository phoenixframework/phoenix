defmodule Mix.Tasks.Phoenix.Des.Html do
  use Mix.Task

  @shortdoc "Destroys controller, model and views for an HTML based resource"

  @moduledoc """
  Destroys a Phoenix resource.

      mix phoenix.des.html User users

  The first argument is the module name followed by
  its plural name (used for resources and schema).

  The resources destroyed are:

    * the model in web/models
    * the view in web/views
    * the controller in web/controllers
    * the migration file for the repository  (note: this task does not rollback the migration)
    * default CRUD templates in web/templates
    * the generated test files for the model and controller

  Removal of the model can be skipped with `--no-model`.
  Read the documentation for `phoenix.des.model` for more
  information on namespaced resources.
  """
  def run(args) do
    switches = [binary_id: :boolean, model: :boolean]

    {opts, parsed, _} = OptionParser.parse(args, switches: switches)
    [singular, plural | attrs] = validate_args!(parsed)

    default_opts = Application.get_env(:phoenix, :generators, [])
    opts = Keyword.merge(default_opts, opts)

    attrs   = Mix.Phoenix.attrs(attrs)
    binding = Mix.Phoenix.inflect(singular)
    path    = binding[:path]
    route   = String.split(path, "/") |> Enum.drop(-1) |> Kernel.++([plural]) |> Enum.join("/")
    binding = binding ++ [plural: plural, route: route, attrs: attrs,
                          binary_id: opts[:binary_id],
                          inputs: inputs(attrs), params: Mix.Phoenix.params(attrs),
                          template_singular: String.replace(binding[:singular], "_", " "),
                          template_plural: String.replace(plural, "_", " ")]

    Mix.shell.info("""

      WARNING: mix phoenix.des.html will DELETE the following files:

    """)

    files = [
      "web/controllers/#{path}_controller.ex",
      "web/templates/#{path}/edit.html.eex",
      "web/templates/#{path}/form.html.eex",
      "web/templates/#{path}/index.html.eex",
      "web/templates/#{path}/new.html.eex",
      "web/templates/#{path}/show.html.eex",
      "web/views/#{path}_view.ex",
      "test/controllers/#{path}_controller_test.exs"
    ]
    if opts[:model] != false do
      files = List.flatten(files, Mix.Tasks.Phoenix.Des.Model.files(path, true))
    end
    Enum.each(files, fn(x) -> Mix.shell.info(x) end)
    Mix.shell.info ""

    if Mix.shell.yes?("Are you sure you want these files destroyed?") do
      Enum.each(files, fn(x) -> File.rm!(x) end)
      instructions = """

      Also, remember to remove the resource from your browser scope in web/router.ex:

          resources "/#{route}", #{binding[:scoped]}Controller
      """
      Mix.shell.info instructions
    else
      Mix.shell.info "Operation canceled, no files removed."
    end
  end

  defp validate_args!([_, plural | _] = args) do
    cond do
      String.contains?(plural, ":") ->
        raise_with_help
      plural != Phoenix.Naming.underscore(plural) ->
        Mix.raise "expected the second argument, #{inspect plural}, to be all lowercase using snake_case convention"
      true ->
        args
    end
  end

  defp validate_args!(_) do
    raise_with_help
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.des.html expects both singular and plural names
    of the resource:

        mix phoenix.des.html User users
    """
  end

  defp inputs(attrs) do
    Enum.map attrs, fn
      {_, {:array, _}} ->
        {nil, nil, nil}
      {_, {:references, _}} ->
        {nil, nil, nil}
      {key, :integer}    ->
        {label(key), ~s(<%= number_input f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :float}      ->
        {label(key), ~s(<%= number_input f, #{inspect(key)}, step: "any", class: "form-control" %>), error(key)}
      {key, :decimal}    ->
        {label(key), ~s(<%= number_input f, #{inspect(key)}, step: "any", class: "form-control" %>), error(key)}
      {key, :boolean}    ->
        {label(key), ~s(<%= checkbox f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :text}       ->
        {label(key), ~s(<%= textarea f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :date}       ->
        {label(key), ~s(<%= date_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :time}       ->
        {label(key), ~s(<%= time_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, :datetime}   ->
        {label(key), ~s(<%= datetime_select f, #{inspect(key)}, class: "form-control" %>), error(key)}
      {key, _}           ->
        {label(key), ~s(<%= text_input f, #{inspect(key)}, class: "form-control" %>), error(key)}
    end
  end

  defp label(key) do
    ~s(<%= label f, #{inspect(key)}, class: "control-label" %>)
  end

  defp error(field) do
    ~s(<%= error_tag f, #{inspect(field)} %>)
  end
end
