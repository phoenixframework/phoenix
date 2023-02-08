defmodule Mix.Tasks.Phx.Gen.Live do
  @shortdoc "Generates LiveView, templates, and context for a resource"

  @moduledoc """
  Generates LiveView, templates, and context for a resource.

      mix phx.gen.live Accounts User users name:string age:integer

  The first argument is the context module.  The context is an Elixir module
  that serves as an API boundary for the given resource. A context often holds
  many related resources.  Therefore, if the context already exists, it will be
  augmented with functions for the given resource.

  The second argument is the schema module.  The schema is responsible for
  mapping the database fields into an Elixir struct.

  The remaining arguments are the schema module plural name (used as the schema
  table name), and an optional list of attributes as their respective names and
  types.  See `mix help phx.gen.schema` for more information on attributes.

  When this command is run for the first time, a `Components` module will be
  created if it does not exist, along with the resource level LiveViews and
  components, including `UserLive.Index`, `UserLive.Show`, and
  `UserLive.FormComponent` modules for the new resource.

  > Note: A resource may also be split
  > over distinct contexts (such as `Accounts.User` and `Payments.User`).

  Overall, this generator will add the following files:

    * a context module in `lib/app/accounts.ex` for the accounts API
    * a schema in `lib/app/accounts/user.ex`, with a `users` table
    * a LiveView in `lib/app_web/live/user_live/show.ex`
    * a LiveView in `lib/app_web/live/user_live/index.ex`
    * a LiveComponent in `lib/app_web/live/user_live/form_component.ex`
    * a helpers module in `lib/app_web/live/live_helpers.ex` with a modal

  After file generation is complete, there will be output regarding required
  updates to the lib/app_web/router.ex file.

      Add the live routes to your browser scope in lib/app_web/router.ex:

        live "/users", UserLive.Index, :index
        live "/users/new", UserLive.Index, :new
        live "/users/:id/edit", UserLive.Index, :edit

        live "/users/:id", UserLive.Show, :show
        live "/users/:id/show/edit", UserLive.Show, :edit

  ## The context app

  A migration file for the repository and test files for the context and
  controller features will also be generated.

  The location of the web files (LiveView's, views, templates, etc.) in an
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

      mix phx.gen.live Accounts User users --context-app warehouse

  ## Web namespace

  By default, the LiveView modules will be namespaced by the web module.
  You can customize the web module namespace by passing the `--web` flag with a
  module name, for example:

      mix phx.gen.live Accounts User users --web Sales

  Which would generate the LiveViews in `lib/app_web/live/sales/user_live/`,
  namespaced `AppWeb.Sales.UserLive` instead of `AppWeb.UserLive`.

  ## Customizing the context, schema, tables and migrations

  In some cases, you may wish to bootstrap HTML templates, LiveViews,
  and tests, but leave internal implementation of the context or schema
  to yourself. You can use the `--no-context` and `--no-schema` flags
  for file generation control.

  You can also change the table name or configure the migrations to
  use binary ids for primary keys, see `mix help phx.gen.schema` for more
  information.
  """
  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.live must be invoked from within your *_web application root directory"
      )
    end

    {context, schema} = Gen.Context.build(args)
    Gen.Context.prompt_for_code_injection(context)

    binding = [context: context, schema: schema, inputs: inputs(schema)]
    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context)

    context
    |> copy_new_files(binding, paths)
    |> maybe_inject_imports()
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
    web_live = Path.join([web_prefix, "live", web_path, live_subdir])
    test_live = Path.join([test_prefix, "live", web_path])

    [
      {:eex, "show.ex", Path.join(web_live, "show.ex")},
      {:eex, "index.ex", Path.join(web_live, "index.ex")},
      {:eex, "form_component.ex", Path.join(web_live, "form_component.ex")},
      {:eex, "index.html.heex", Path.join(web_live, "index.html.heex")},
      {:eex, "show.html.heex", Path.join(web_live, "show.html.heex")},
      {:eex, "live_test.exs", Path.join(test_live, "#{schema.singular}_live_test.exs")},
      {:new_eex, "core_components.ex",
       Path.join([web_prefix, "components", "core_components.ex"])}
    ]
  end

  defp copy_new_files(%Context{} = context, binding, paths) do
    files = files_to_be_generated(context)

    binding =
      Keyword.merge(binding,
        assigns: %{
          web_namespace: inspect(context.web_module),
          gettext: true
        }
      )

    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.live", binding, files)
    if context.generate?, do: Gen.Context.copy_new_files(context, paths, binding)

    context
  end

  defp maybe_inject_imports(%Context{context_app: ctx_app} = context) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    [lib_prefix, web_dir] = Path.split(web_prefix)
    file_path = Path.join(lib_prefix, "#{web_dir}.ex")
    file = File.read!(file_path)
    inject = "import #{inspect(context.web_module)}.CoreComponents"

    if String.contains?(file, inject) do
      :ok
    else
      do_inject_imports(context, file, file_path, inject)
    end

    context
  end

  defp do_inject_imports(context, file, file_path, inject) do
    Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path)])

    new_file =
      String.replace(
        file,
        "use Phoenix.Component",
        "use Phoenix.Component\n      #{inject}"
      )

    if file != new_file do
      File.write!(file_path, new_file)
    else
      Mix.shell().info("""

      Could not find use Phoenix.Component in #{file_path}.

      This typically happens because your application was not generated
      with the --live flag:

          mix phx.new my_app --live

      Please make sure LiveView is installed and that #{inspect(context.web_module)}
      defines both `live_view/0` and `live_component/0` functions,
      and that both functions import #{inspect(context.web_module)}.CoreComponents.
      """)
    end
  end

  @doc false
  def print_shell_instructions(%Context{schema: schema, context_app: ctx_app} = context) do
    prefix = Module.concat(context.web_module, schema.web_namespace)
    web_path = Mix.Phoenix.web_path(ctx_app)

    if schema.web_namespace do
      Mix.shell().info("""

      Add the live routes to your #{schema.web_namespace} :browser scope in #{web_path}/router.ex:

          scope "/#{schema.web_path}", #{inspect(prefix)}, as: :#{schema.web_path} do
            pipe_through :browser
            ...

      #{for line <- live_route_instructions(schema), do: "      #{line}"}
          end
      """)
    else
      Mix.shell().info("""

      Add the live routes to your browser scope in #{Mix.Phoenix.web_path(ctx_app)}/router.ex:

      #{for line <- live_route_instructions(schema), do: "    #{line}"}
      """)
    end

    if context.generate?, do: Gen.Context.print_shell_instructions(context)
    maybe_print_upgrade_info()
  end

  defp maybe_print_upgrade_info do
    unless Code.ensure_loaded?(Phoenix.LiveView.JS) do
      Mix.shell().info("""

      You must update :phoenix_live_view to v0.18 or later and
      :phoenix_live_dashboard to v0.7 or later to use the features
      in this generator.
      """)
    end
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

  @doc false
  def inputs(%Schema{} = schema) do
    Enum.map(schema.attrs, fn
      {_, {:references, _}} ->
        nil

      {key, :integer} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="number" label="#{label(key)}" />)

      {key, :float} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="number" label="#{label(key)}" step="any" />)

      {key, :decimal} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="number" label="#{label(key)}" step="any" />)

      {key, :boolean} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="checkbox" label="#{label(key)}" />)

      {key, :text} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="text" label="#{label(key)}" />)

      {key, :date} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="date" label="#{label(key)}" />)

      {key, :time} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="time" label="#{label(key)}" />)

      {key, :utc_datetime} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="datetime-local" label="#{label(key)}" />)

      {key, :naive_datetime} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="datetime-local" label="#{label(key)}" />)

      {key, {:array, _} = type} ->
        ~s"""
        <.input
          field={@form[#{inspect(key)}]}
          type="select"
          multiple
          label="#{label(key)}"
          options={#{inspect(default_options(type))}}
        />
        """

      {key, {:enum, _}} ->
        ~s"""
        <.input
          field={@form[#{inspect(key)}]}
          type="select"
          label="#{label(key)}"
          prompt="Choose a value"
          options={Ecto.Enum.values(#{inspect(schema.module)}, #{inspect(key)})}
        />
        """

      {key, _} ->
        ~s(<.input field={@form[#{inspect(key)}]} type="text" label="#{label(key)}" />)
    end)
  end

  defp default_options({:array, :string}),
    do: Enum.map([1, 2], &{"Option #{&1}", "option#{&1}"})

  defp default_options({:array, :integer}),
    do: Enum.map([1, 2], &{"#{&1}", &1})

  defp default_options({:array, _}), do: []

  defp label(key), do: Phoenix.Naming.humanize(to_string(key))
end
