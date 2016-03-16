defmodule Mix.Tasks.Phoenix.Des.Json do
  use Mix.Task

  @shortdoc "Destroys a controller and model for a JSON based resource"

  @moduledoc """
  Destroys a Phoenix resource.

      mix phoenix.des.json User users name:string age:integer

  The first argument is the module name followed by
  its plural name.

  The resource files destroyed include:

    * a schema in web/models
    * a view in web/views
    * a controller in web/controllers
    * a migration file for the repository
    * test files for generated model and controller

  To keep the model specify the `--no-model` option.
  Read the documentation for `phoenix.des.model`
  for more information on namespaced resources.
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
    binding = binding ++ [plural: plural, route: route,
                          sample_id: sample_id(opts),
                          attrs: attrs, params: Mix.Phoenix.params(attrs)]

    Mix.shell.info("""

      WARNING: mix phoenix.des.json will DELETE the following files:

    """)

    files = [
      "web/controllers/#{path}_controller.ex",
      "web/views/#{path}_view.ex",
      "test/controllers/#{path}_controller_test.exs"
    ] ++ changeset_view()
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

  defp sample_id(opts) do
    if Keyword.get(opts, :binary_id, false) do
      Keyword.get(opts, :sample_binary_id, "11111111-1111-1111-1111-111111111111")
    else
      -1
    end
  end

  defp changeset_view do
    if File.exists?("web/views/changeset_view.ex") do
      []
    else
      ["web/views/changeset_view.ex"]
    end
  end

  defp validate_args!([_, plural | _] = args) do
    cond do
      String.contains?(plural, ":") ->
        raise_with_help
      plural != Phoenix.Naming.underscore(plural) ->
        Mix.raise "Expected the second argument, #{inspect plural}, to be all lowercase using snake_case convention"
      true ->
        args
    end
  end

  defp validate_args!(_) do
    raise_with_help
  end

  defp raise_with_help do
    Mix.raise """
    mix phoenix.des.json expects both singular and plural names
    of the resource:

        mix phoenix.des.json User users
    """
  end
end
