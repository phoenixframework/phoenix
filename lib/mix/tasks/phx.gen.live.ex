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

  When this command is run for the first time, a `ModalComponent` and
  `LiveHelpers` module will be created, along with the resource level
  LiveViews and components, including an `IndexLive`, `ShowLive`, `FormComponent`
  for the new resource.

  > Note: A resource may also be split
  > over distinct contexts (such as `Accounts.User` and `Payments.User`).

  The schema is responsible for mapping the database fields into an
  Elixir struct. It is followed by an optional list of attributes,
  with their respective names and types. See `mix phx.gen.schema`
  for more information on attributes.

  Overall, this generator will add the following files to `lib/`:

    * a context module in `lib/app/accounts.ex` for the accounts API
    * a schema in `lib/app/accounts/user.ex`, with an `users` table
    * a view in `lib/app_web/views/user_view.ex`
    * a LiveView in `lib/app_web/live/user_live/show_live.ex`
    * a LiveView in `lib/app_web/live/user_live/index_live.ex`
    * a LiveComponent in `lib/app_web/live/user_live/form_component.ex`
    * a LiveComponent in `lib/app_web/live/modal_component.ex`
    * a helpers modules in `lib/app_web/live/live_helpers.ex`

  ## The context app

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

  ## Customising the context, schema, tables and migrations

  In some cases, you may wish to bootstrap HTML templates, LiveViews,
  and tests, but leave internal implementation of the context or schema
  to yourself. You can use the `--no-context` and `--no-schema` flags
  for file generation control.

  You can also change the table name or configure the migrations to
  use binary ids for primary keys, see `mix phx.gen.schema` for more
  information.
  """
  use Mix.Task

  alias Mix.Phoenix.{Context}
  alias Mix.Tasks.Phx.Gen

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise "mix phx.gen.live must be invoked from within your *_web application root directory"
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
      {:eex, "show.ex",                   Path.join([web_prefix, "live", web_path, live_subdir, "show.ex"])},
      {:eex, "index.ex",                  Path.join([web_prefix, "live", web_path, live_subdir, "index.ex"])},
      {:eex, "form_component.ex",         Path.join([web_prefix, "live", web_path, live_subdir, "form_component.ex"])},
      {:eex, "form_component.html.leex",  Path.join([web_prefix, "live", web_path, live_subdir, "form_component.html.leex"])},
      {:eex, "index.html.leex",           Path.join([web_prefix, "live", web_path, live_subdir, "index.html.leex"])},
      {:eex, "show.html.leex",            Path.join([web_prefix, "live", web_path, live_subdir, "show.html.leex"])},
      {:eex, "live_test.exs",             Path.join([test_prefix, "live", web_path, "#{schema.singular}_live_test.exs"])},
      {:new_eex, "modal_component.ex",    Path.join([web_prefix, "live", "modal_component.ex"])},
      {:new_eex, "live_helpers.ex",       Path.join([web_prefix, "live", "live_helpers.ex"])},
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

      Could not find Phoenix.LiveView.Helpers imported in #{file_path}.

      This typically happens because your application was not generated
      with the --live flag:

          mix phx.new my_app --live

      Please make sure LiveView is installed and that #{inspect(context.web_module)}
      defines both `live_view/0` and `live_component/0` functions,
      and that both functions import #{inspect(context.web_module)}.LiveHelpers.
      """
    end
  end

  @doc false
  def print_shell_instructions(%Context{schema: schema, context_app: ctx_app} = context) do
    prefix = Module.concat(context.web_module, schema.web_namespace)
    web_path = Mix.Phoenix.web_path(ctx_app)

    if schema.web_namespace do
      Mix.shell().info """

      Add the live routes to your #{schema.web_namespace} :browser scope in #{web_path}/router.ex:

          scope "/#{schema.web_path}", #{inspect prefix}, as: :#{schema.web_path} do
            pipe_through :browser
            ...

      #{for line <- live_route_instructions(schema), do: "      #{line}"}
          end
      """
    else
      Mix.shell().info """

      Add the live routes to your browser scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

      #{for line <- live_route_instructions(schema), do: "    #{line}"}
      """
    end
    if context.generate?, do: Gen.Context.print_shell_instructions(context)
  end

  defp live_route_instructions(schema) do
    [
      ~s|live "/#{schema.plural}", #{inspect(schema.alias)}Live.Index, :index\n|,
      ~s|live "/#{schema.plural}/new", #{inspect(schema.alias)}Live.Index, :new\n|,
      ~s|live "/#{schema.plural}/:id/edit", #{inspect(schema.alias)}Live.Index, :edit\n\n|,
      ~s|live "/#{schema.plural}/:id", #{inspect(schema.alias)}Live.Show, :show\n|,
      ~s|live "/#{schema.plural}/:id/show/edit", #{inspect(schema.alias)}Live.Show, :edit|
    ]
  end
end
