defmodule Mix.Tasks.Phx.Gen.Live do
  @shortdoc "Generates LiveView, templates, and context for a resource"

  @moduledoc """
  Generates LiveView, templates, and context for a resource.

      mix phx.gen.live Accounts User users name:string age:integer

  The first argument is the context module followed by the schema module
  and its plural name (used as the schema table name).

  The context is an Elixir module that serves as an API boundary for
  the given resource. A context often holds many related resources.
  Therefore, if the context already exists, it will be augmented with
  functions for the given resource.

  > Note: A resource may also be split
  > over distinct contexts (such as `Accounts.User` and `Payments.User`).

  The schema is responsible for mapping the database fields into an
  Elixir struct.

  Overall, this generator will add the following files to `lib/`:

    * a context module in `lib/app/accounts.ex` for the accounts API
    * a schema in `lib/app/accounts/user.ex`, with an `users` table
    * a view in `lib/app_web/views/user_view.ex`
    * a LiveView in `lib/app_web/live/user_live/show.ex`
    * a LiveView in `lib/app_web/live/user_live/index.ex`
    * a LiveComponent in `lib/app_web/live/user_live/form.ex`
    * default CRUD templates in `lib/app_web/templates/user`

  A migration file for the repository and test files for the context and
  controller features will also be generated.

  The location of the web files (LiveView's, views, templates, etc) in an
  umbrella application will vary based on the `:context_app` config located
  in your applications `:generators` configuration. When set, the Phoenix
  generators will generate web files directly in your lib and test folders
  since the application is assumed to be isolated to web specific functionality.
  If `:context_app` is not set, the generators will place web related lib
  and test files in a `web/` directory since the application is assumed
  to be handling both web and domain specific functionality.
  Example configuration:

      config :my_app_web, :generators, context_app: :my_app

  Alternatively, the `--context-app` option may be supplied to the generator:

      mix phx.gen.live Sales User users --context-app warehouse

  ## Web namespace

  By default, the controller and view will be namespaced by the schema name.
  You can customize the web module namespace by passing the `--web` flag with a
  module name, for example:

      mix phx.gen.live Sales User users --web Sales

  Which would generate a LiveViews inside `lib/app_web/live/sales/user_live/` and a
  view at `lib/app_web/views/sales/user_view.ex`.

  ## Generating without a schema or context file

  In some cases, you may wish to bootstrap HTML templates, LiveViews, and
  tests, but leave internal implementation of the context or schema
  to yourself. You can use the `--no-context` and `--no-schema` flags for
  file generation control.

  ## table

  By default, the table name for the migration and schema will be
  the plural name provided for the resource. To customize this value,
  a `--table` option may be provided. For example:

      mix phx.gen.live Accounts User users --table cms_users

  ## binary_id

  Generated migration can use `binary_id` for schema's primary key
  and its references with option `--binary-id`.

  ## Default options

  This generator uses default options provided in the `:generators`
  configuration of your application. These are the defaults:

      config :your_app, :generators,
        migration: true,
        binary_id: false,
        sample_binary_id: "11111111-1111-1111-1111-111111111111"

  You can override those options per invocation by providing corresponding
  switches, e.g. `--no-binary-id` to use normal ids despite the default
  configuration or `--migration` to force generation of the migration.

  Read the documentation for `phx.gen.schema` for more information on
  attributes.
  """
  use Mix.Task

  alias Mix.Phoenix.{Context}
  alias Mix.Tasks.Phx.Gen

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.live can only be run inside an application directory"
    end

    {context, schema} = Gen.Context.build(args)
    Gen.Context.prompt_for_code_injection(context)

    binding = [context: context, schema: schema, inputs: Gen.Html.inputs(schema)]
    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context)

    context
    |> copy_new_files(binding, paths)
    |> maybe_inject_helpers()
    |> print_shell_instructions()
  end

  defp prompt_for_conflicts(context) do
    context
    |> files_to_be_generated()
    |> Kernel.++(context_files(context))
    |> Mix.Phoenix.prompt_for_conflicts()
  end
  defp context_files(%Context{generate?: true} = context) do
    Gen.Context.files_to_be_generated(context)
  end
  defp context_files(%Context{generate?: false}) do
    []
  end

  defp files_to_be_generated(%Context{schema: schema, context_app: context_app}) do
    web_prefix = Mix.Phoenix.web_path(context_app)
    test_prefix = Mix.Phoenix.web_test_path(context_app)
    web_path = to_string(schema.web_path)
    live_subdir = "#{schema.singular}_live"

    [
      {:eex, "show.ex",         Path.join([web_prefix, "live", web_path, live_subdir, "show.ex"])},
      {:eex, "index.ex",        Path.join([web_prefix, "live", web_path, live_subdir, "index.ex"])},
      {:eex, "form.ex",         Path.join([web_prefix, "live", web_path, live_subdir, "form.ex"])},
      {:eex, "form.html.leex",  Path.join([web_prefix, "templates", web_path, schema.singular, "form.html.leex"])},
      {:eex, "index.html.leex", Path.join([web_prefix, "templates", web_path, schema.singular, "index.html.leex"])},
      {:eex, "show.html.leex",  Path.join([web_prefix, "templates", web_path, schema.singular, "show.html.leex"])},
      {:eex, "view.ex",         Path.join([web_prefix, "views", web_path, "#{schema.singular}_view.ex"])},
      {:eex, "live_test.exs",   Path.join([test_prefix, "live", web_path, "#{schema.singular}_live_test.exs"])},
      {:new_eex, "modal.ex",        Path.join([web_prefix, "live", "modal.ex"])},
      {:new_eex, "live_helpers.ex", Path.join([web_prefix, "live", "live_helpers.ex"])},
    ]
  end

  defp copy_new_files(%Context{} = context, binding, paths) do
    files = files_to_be_generated(context)
    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.live", binding, files)
    if context.generate?, do: Gen.Context.copy_new_files(context, paths, binding)

    context
  end

  defp maybe_inject_helpers(%Context{context_app: ctx_app} = context) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    [lib_prefix, web_dir] = Path.split(web_prefix)
    file_path = Path.join(lib_prefix, "#{web_dir}.ex")
    file = File.read!(file_path)
    inject = "import #{inspect(context.web_module)}.LiveHelpers"

    if String.contains?(file, inject) do
      :ok
    else
      do_inject_helpers(context, file, file_path, inject)
    end

    context
  end

  defp do_inject_helpers(context, file, file_path, inject) do
    Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path)])

    new_file = String.replace(file, "import Phoenix.LiveView.Helpers", "import Phoenix.LiveView.Helpers\n      #{inject}")
    if file != new_file do
      File.write!(file_path, new_file)
    else
      Mix.shell().info """

      Add your #{inspect(context.web_module)}.LiveHelpers import to your view_helpers block in #{file_path}:

          defp view_helpers do
            quote do
              # Use all HTML functionality (forms, tags, etc)
              use Phoenix.HTML

              # Import convenience functions for LiveView rendering
              import Phoenix.LiveView.Helpers
              #{inject}
              ...
            end
          end
      """
    end
  end

  @doc false
  def print_shell_instructions(%Context{schema: schema, context_app: ctx_app} = context) do
    if schema.web_namespace do
      Mix.shell().info """

      Add the live routes to your #{schema.web_namespace} :browser scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

          scope "/#{schema.web_path}", #{inspect Module.concat(context.web_module, schema.web_namespace)}, as: :#{schema.web_path} do
            pipe_through :browser
            ...

            live "/#{schema.plural}", #{inspect(schema.alias)}Live.Index, :index
            live "/#{schema.plural}/new", #{inspect(schema.alias)}Live.Index, :new
            live "/#{schema.plural}/:id/edit", #{inspect(schema.alias)}Live.Index, :edit

            live "/#{schema.plural}/:id", #{inspect(schema.alias)}Live.Show, :show
            live "/#{schema.plural}/:id/show/edit", #{inspect(schema.alias)}Live.Show, :edit
          end
      """
    else
      Mix.shell().info """

      Add the live routes to your browser scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

          live "/#{schema.plural}", #{inspect(schema.alias)}Live.Index, :index
          live "/#{schema.plural}/new", #{inspect(schema.alias)}Live.Index, :new
          live "/#{schema.plural}/:id/edit", #{inspect(schema.alias)}Live.Index, :edit

          live "/#{schema.plural}/:id", #{inspect(schema.alias)}Live.Show, :show
          live "/#{schema.plural}/:id/show/edit", #{inspect(schema.alias)}Live.Show, :edit
      """
    end
    if context.generate?, do: Gen.Context.print_shell_instructions(context)
  end
end
