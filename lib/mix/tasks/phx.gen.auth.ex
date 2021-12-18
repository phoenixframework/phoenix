defmodule Mix.Tasks.Phx.Gen.Auth do
  @shortdoc "Generates authentication logic for a resource"

  @moduledoc """
  Generates authentication logic for a resource.

      $ mix phx.gen.auth Accounts User users

  The first argument is the context module followed by the schema module
  and its plural name (used as the schema table name).

  Additional information and security considerations are detailed in the
  [`mix phx.gen.auth` guide](mix_phx_gen_auth.html).

  ## Password hashing

  The password hashing mechanism defaults to `bcrypt` for
  Unix systems and `pbkdf2` for Windows systems. Both
  systems use the [Comeonin interface](https://hexdocs.pm/comeonin/).

  The password hashing mechanism can be overridden with the
  `--hashing-lib` option. The following values are supported:

    * `bcrypt` - [bcrypt_elixir](https://hex.pm/packages/bcrypt_elixir)
    * `pbkdf2` - [pbkdf2_elixir](https://hex.pm/packages/pbkdf2_elixir)
    * `argon2` - [argon2_elixir](https://hex.pm/packages/argon2_elixir)

  We recommend developers to consider using `argon2`, which
  is the most robust of all 3. The downside is that `argon2`
  is quite CPU and memory intensive, and you will need more
  powerful instances to run your applications on.

  For more information about choosing these libraries, see the
  [Comeonin project](https://github.com/riverrun/comeonin).

  ## Web namespace

  By default, the controllers and view will be namespaced by the schema name.
  You can customize the web module namespace by passing the `--web` flag with a
  module name, for example:

      $ mix phx.gen.auth Accounts User users --web Warehouse

  Which would generate the controllers, views, templates and associated tests nested in the `MyAppWeb.Warehouse` namespace:

    * `lib/my_app_web/controllers/warehouse/user_auth.ex`
    * `lib/my_app_web/controllers/warehouse/user_confirmation_controller.ex`
    * `lib/my_app_web/views/warehouse/user_confirmation_view.ex`
    * `lib/my_app_web/templates/warehouse/user_confirmation/new.html.heex`
    * `test/my_app_web/controllers/warehouse/user_auth_test.exs`
    * `test/my_app_web/controllers/warehouse/user_confirmation_controller_test.exs`
    * and so on...

  ## Binary ids

  The `--binary-id` option causes the generated migration to use
  `binary_id` for its primary key and foreign keys.

  ## Default options

  This generator uses default options provided in the `:generators`
  configuration of your application. These are the defaults:

      config :your_app, :generators,
        binary_id: false,
        sample_binary_id: "11111111-1111-1111-1111-111111111111"

  You can override those options per invocation by providing corresponding
  switches, e.g. `--no-binary-id` to use normal ids despite the default
  configuration.

  ## Custom table names

  By default, the table name for the migration and schema will be
  the plural name provided for the resource. To customize this value,
  a `--table` option may be provided. For example:

      $ mix phx.gen.auth Accounts User users --table accounts_users

  This will cause the generated tables to be named `"accounts_users"` and `"accounts_users_tokens"`.
  """

  use Mix.Task

  alias Mix.Phoenix.{Context, Schema}
  alias Mix.Tasks.Phx.Gen
  alias Mix.Tasks.Phx.Gen.Auth.{HashingLibrary, Injector, Migration}

  @switches [
    web: :string,
    binary_id: :boolean,
    hashing_lib: :string,
    table: :string,
    merge_with_existing_context: :boolean,
    prefix: :string
  ]

  @doc false
  def run(args, test_opts \\ []) do
    if Mix.Project.umbrella?() do
      Mix.raise("mix phx.gen.auth can only be run inside an application directory")
    end

    {opts, parsed} = OptionParser.parse!(args, strict: @switches)
    validate_args!(parsed)
    hashing_library = build_hashing_library!(opts)

    context_args = OptionParser.to_argv(opts, switches: @switches) ++ parsed

    {context, schema} = Gen.Context.build(context_args, __MODULE__)
    Gen.Context.prompt_for_code_injection(context)

    if Keyword.get(test_opts, :validate_dependencies?, true) do
      # Needed so we can get the ecto adapter and ensure other
      # libraries are loaded.
      Mix.Task.run("compile")

      validate_required_dependencies!()
    end

    ecto_adapter =
      Keyword.get_lazy(
        test_opts,
        :ecto_adapter,
        fn -> get_ecto_adapter!(schema) end
      )

    migration = Migration.build(ecto_adapter)

    binding = [
      context: context,
      schema: schema,
      migration: migration,
      hashing_library: hashing_library,
      web_app_name: web_app_name(context),
      endpoint_module: Module.concat([context.web_module, Endpoint]),
      auth_module: Module.concat([context.web_module, schema.web_namespace, "#{inspect(schema.alias)}Auth"]),
      router_scope: router_scope(context),
      web_path_prefix: web_path_prefix(schema),
      test_case_options: test_case_options(ecto_adapter)
    ]

    paths = generator_paths()

    prompt_for_conflicts(context)

    context
    |> copy_new_files(binding, paths)
    |> inject_conn_case_helpers(paths, binding)
    |> inject_config(hashing_library)
    |> maybe_inject_mix_dependency(hashing_library)
    |> inject_routes(paths, binding)
    |> maybe_inject_router_import(binding)
    |> maybe_inject_router_plug()
    |> maybe_inject_app_layout_menu()
    |> Gen.Notifier.maybe_print_mailer_installation_instructions()
    |> print_shell_instructions()
  end

  defp web_app_name(%Context{} = context) do
    context.web_module
    |> inspect()
    |> Phoenix.Naming.underscore()
  end

  defp validate_args!([_, _, _]), do: :ok

  defp validate_args!(_) do
    raise_with_help("Invalid arguments")
  end

  defp validate_required_dependencies! do
    unless Code.ensure_loaded?(Ecto.Adapters.SQL) do
      raise_with_help("mix phx.gen.auth requires ecto_sql", :phx_generator_args)
    end

    if generated_with_no_html?() do
      raise_with_help("mix phx.gen.auth requires phoenix_html", :phx_generator_args)
    end
  end

  defp generated_with_no_html? do
    Mix.Project.config()
    |> Keyword.get(:deps, [])
    |> Enum.any?(fn
      {:phoenix_html, _} -> true
      {:phoenix_html, _, _} -> true
      _ -> false
    end)
    |> Kernel.not()
  end

  defp build_hashing_library!(opts) do
    opts
    |> Keyword.get_lazy(:hashing_lib, &default_hashing_library_option/0)
    |> HashingLibrary.build()
    |> case do
      {:ok, hashing_library} ->
        hashing_library

      {:error, {:unknown_library, unknown_library}} ->
        raise_with_help("Unknown value for --hashing-lib #{inspect(unknown_library)}", :hashing_lib)
    end
  end

  defp default_hashing_library_option do
    case :os.type() do
      {:unix, _} -> "bcrypt"
      {:win32, _} -> "pbkdf2"
    end
  end

  defp prompt_for_conflicts(context) do
    context
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  defp files_to_be_generated(%Context{schema: schema, context_app: context_app} = context) do
    web_prefix = Mix.Phoenix.web_path(context_app)
    web_test_prefix = Mix.Phoenix.web_test_path(context_app)
    migrations_prefix = Mix.Phoenix.context_app_path(context_app, "priv/repo/migrations")
    web_path = to_string(schema.web_path)

    [
      {:eex, "migration.ex", Path.join([migrations_prefix, "#{timestamp()}_create_#{schema.table}_auth_tables.exs"])},
      {:eex, "notifier.ex", Path.join([context.dir, "#{schema.singular}_notifier.ex"])},
      {:eex, "schema.ex", Path.join([context.dir, "#{schema.singular}.ex"])},
      {:eex, "schema_token.ex", Path.join([context.dir, "#{schema.singular}_token.ex"])},
      {:eex, "auth.ex", Path.join([web_prefix, "controllers", web_path, "#{schema.singular}_auth.ex"])},
      {:eex, "auth_test.exs", Path.join([web_test_prefix, "controllers", web_path, "#{schema.singular}_auth_test.exs"])},
      {:eex, "confirmation_view.ex", Path.join([web_prefix, "views", web_path, "#{schema.singular}_confirmation_view.ex"])},
      {:eex, "confirmation_new.html.heex", Path.join([web_prefix, "templates", web_path, "#{schema.singular}_confirmation", "new.html.heex"])},
      {:eex, "confirmation_edit.html.heex", Path.join([web_prefix, "templates", web_path, "#{schema.singular}_confirmation", "edit.html.heex"])},
      {:eex, "confirmation_controller.ex", Path.join([web_prefix, "controllers", web_path, "#{schema.singular}_confirmation_controller.ex"])},
      {:eex, "confirmation_controller_test.exs", Path.join([web_test_prefix, "controllers", web_path, "#{schema.singular}_confirmation_controller_test.exs"])},
      {:eex, "_menu.html.heex", Path.join([web_prefix, "templates", "layout", "_#{schema.singular}_menu.html.heex"])},
      {:eex, "registration_new.html.heex", Path.join([web_prefix, "templates", web_path, "#{schema.singular}_registration", "new.html.heex"])},
      {:eex, "registration_controller.ex", Path.join([web_prefix, "controllers", web_path, "#{schema.singular}_registration_controller.ex"])},
      {:eex, "registration_controller_test.exs", Path.join([web_test_prefix, "controllers", web_path, "#{schema.singular}_registration_controller_test.exs"])},
      {:eex, "registration_view.ex", Path.join([web_prefix, "views", web_path, "#{schema.singular}_registration_view.ex"])},
      {:eex, "reset_password_view.ex", Path.join([web_prefix, "views", web_path, "#{schema.singular}_reset_password_view.ex"])},
      {:eex, "reset_password_controller.ex", Path.join([web_prefix, "controllers", web_path, "#{schema.singular}_reset_password_controller.ex"])},
      {:eex, "reset_password_controller_test.exs",
       Path.join([web_test_prefix, "controllers", web_path, "#{schema.singular}_reset_password_controller_test.exs"])},
      {:eex, "reset_password_edit.html.heex", Path.join([web_prefix, "templates", web_path, "#{schema.singular}_reset_password", "edit.html.heex"])},
      {:eex, "reset_password_new.html.heex", Path.join([web_prefix, "templates", web_path, "#{schema.singular}_reset_password", "new.html.heex"])},
      {:eex, "session_view.ex", Path.join([web_prefix, "views", web_path, "#{schema.singular}_session_view.ex"])},
      {:eex, "session_controller.ex", Path.join([web_prefix, "controllers", web_path, "#{schema.singular}_session_controller.ex"])},
      {:eex, "session_controller_test.exs", Path.join([web_test_prefix, "controllers", web_path, "#{schema.singular}_session_controller_test.exs"])},
      {:eex, "session_new.html.heex", Path.join([web_prefix, "templates", web_path, "#{schema.singular}_session", "new.html.heex"])},
      {:eex, "settings_view.ex", Path.join([web_prefix, "views", web_path, "#{schema.singular}_settings_view.ex"])},
      {:eex, "settings_edit.html.heex", Path.join([web_prefix, "templates", web_path, "#{schema.singular}_settings", "edit.html.heex"])},
      {:eex, "settings_controller.ex", Path.join([web_prefix, "controllers", web_path, "#{schema.singular}_settings_controller.ex"])},
      {:eex, "settings_controller_test.exs", Path.join([web_test_prefix, "controllers", web_path, "#{schema.singular}_settings_controller_test.exs"])}
    ]
  end

  defp copy_new_files(%Context{} = context, binding, paths) do
    files = files_to_be_generated(context)
    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.auth", binding, files)
    inject_context_functions(context, paths, binding)
    inject_tests(context, paths, binding)
    inject_context_test_fixtures(context, paths, binding)

    context
  end

  defp inject_context_functions(%Context{file: file} = context, paths, binding) do
    Gen.Context.ensure_context_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/context_functions.ex", binding)
    |> prepend_newline()
    |> inject_before_final_end(file)
  end

  defp inject_tests(%Context{test_file: test_file} = context, paths, binding) do
    Gen.Context.ensure_test_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/test_cases.exs", binding)
    |> prepend_newline()
    |> inject_before_final_end(test_file)
  end

  defp inject_context_test_fixtures(%Context{test_fixtures_file: test_fixtures_file} = context, paths, binding) do
    Gen.Context.ensure_test_fixtures_file_exists(context, paths, binding)

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/context_fixtures_functions.ex", binding)
    |> prepend_newline()
    |> inject_before_final_end(test_fixtures_file)
  end

  defp inject_conn_case_helpers(%Context{} = context, paths, binding) do
    test_file = "test/support/conn_case.ex"

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/conn_case.exs", binding)
    |> inject_before_final_end(test_file)

    context
  end

  defp inject_routes(%Context{context_app: ctx_app} = context, paths, binding) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    file_path = Path.join(web_prefix, "router.ex")

    paths
    |> Mix.Phoenix.eval_from("priv/templates/phx.gen.auth/routes.ex", binding)
    |> inject_before_final_end(file_path)

    context
  end

  defp maybe_inject_mix_dependency(%Context{context_app: ctx_app} = context, %HashingLibrary{mix_dependency: mix_dependency}) do
    file_path = Mix.Phoenix.context_app_path(ctx_app, "mix.exs")

    file = File.read!(file_path)

    case Injector.mix_dependency_inject(file, mix_dependency) do
      {:ok, new_file} ->
        print_injecting(file_path)
        File.write!(file_path, new_file)

      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        Mix.shell().info("""

        Add your #{mix_dependency} dependency to #{file_path}:

            defp deps do
              [
                #{mix_dependency},
                ...
              ]
            end
        """)
    end

    context
  end

  defp maybe_inject_router_import(%Context{context_app: ctx_app} = context, binding) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    file_path = Path.join(web_prefix, "router.ex")
    auth_module = Keyword.fetch!(binding, :auth_module)
    inject = "import #{inspect(auth_module)}"
    use_line = "use #{inspect(context.web_module)}, :router"

    help_text = """
    Add your #{inspect(auth_module)} import to #{Path.relative_to_cwd(file_path)}:

        defmodule #{inspect(context.web_module)}.Router do
          #{use_line}

          # Import authentication plugs
          #{inject}

          ...
        end
    """

    with {:ok, file} <- read_file(file_path),
         {:ok, new_file} <- Injector.inject_unless_contains(file, inject, &String.replace(&1, use_line, "#{use_line}\n\n  #{&2}")) do
      print_injecting(file_path, " - imports")
      File.write!(file_path, new_file)
    else
      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        Mix.shell().info("""

        #{help_text}
        """)

      {:error, {:file_read_error, _}} ->
        print_injecting(file_path)
        print_unable_to_read_file_error(file_path, help_text)
    end

    context
  end

  defp maybe_inject_router_plug(%Context{context_app: ctx_app} = context) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    file_path = Path.join(web_prefix, "router.ex")
    help_text = Injector.router_plug_help_text(file_path, context)

    with {:ok, file} <- read_file(file_path),
         {:ok, new_file} <- Injector.router_plug_inject(file, context) do
      print_injecting(file_path, " - plug")
      File.write!(file_path, new_file)
    else
      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        Mix.shell().info("""

        #{help_text}
        """)

      {:error, {:file_read_error, _}} ->
        print_injecting(file_path)
        print_unable_to_read_file_error(file_path, help_text)
    end

    context
  end

  defp maybe_inject_app_layout_menu(%Context{} = context) do
    schema = context.schema

    if file_path = get_layout_html_path(context) do
      file = File.read!(file_path)

      case Injector.app_layout_menu_inject(file, schema) do
        {:ok, new_file} ->
          print_injecting(file_path)
          File.write!(file_path, new_file)

        :already_injected ->
          :ok

        {:error, :unable_to_inject} ->
          Mix.shell().info("""

          #{Injector.app_layout_menu_help_text(file_path, schema)}
          """)
      end
    else
      menu_name = Injector.app_layout_menu_template_name(schema)
      inject = Injector.app_layout_menu_code_to_inject(schema)

      missing =
        context
        |> potential_layout_file_paths()
        |> Enum.map_join("\n", &"  * #{&1}")

      Mix.shell().error("""

      Unable to find an application layout file to inject a render
      call for #{inspect(menu_name)}.

      Missing files:

      #{missing}

      Please ensure this phoenix app was not generated with
      --no-html. If you have changed the name of your application
      layout file, please add the following code to it where you'd
      like #{inspect(menu_name)} to be rendered.

          #{inject}
      """)
    end

    context
  end

  defp get_layout_html_path(%Context{} = context) do
    context
    |> potential_layout_file_paths()
    |> Enum.find(&File.exists?/1)
  end

  defp potential_layout_file_paths(%Context{context_app: ctx_app}) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)

    for file_name <- ~w(root.html.heex app.html.heex) do
      Path.join([web_prefix, "templates", "layout", file_name])
    end
  end

  defp inject_config(context, %HashingLibrary{} = hashing_library) do
    file_path =
      if Mix.Phoenix.in_umbrella?(File.cwd!()) do
        Path.expand("../../")
      else
        File.cwd!()
      end
      |> Path.join("config/test.exs")

    file =
      case read_file(file_path) do
        {:ok, file} -> file
        {:error, {:file_read_error, _}} -> "use Mix.Config\n"
      end

    case Injector.test_config_inject(file, hashing_library) do
      {:ok, new_file} ->
        print_injecting(file_path)
        File.write!(file_path, new_file)

      :already_injected ->
        :ok

      {:error, :unable_to_inject} ->
        help_text = Injector.test_config_help_text(file_path, hashing_library)

        Mix.shell().info("""

        #{help_text}
        """)
    end

    context
  end

  defp print_shell_instructions(%Context{} = context) do
    Mix.shell().info("""

    Please re-fetch your dependencies with the following command:

        $ mix deps.get

    Remember to update your repository by running migrations:

        $ mix ecto.migrate

    Once you are ready, visit "/#{context.schema.plural}/register"
    to create your account and then access "/dev/mailbox" to
    see the account confirmation email.
    """)

    context
  end

  defp router_scope(%Context{schema: schema} = context) do
    prefix = Module.concat(context.web_module, schema.web_namespace)

    if schema.web_namespace do
      ~s|"/#{schema.web_path}", #{inspect(prefix)}, as: :#{schema.web_path}|
    else
      ~s|"/", #{inspect(context.web_module)}|
    end
  end

  defp web_path_prefix(%Schema{web_path: nil}), do: ""
  defp web_path_prefix(%Schema{web_path: web_path}), do: "/" <> web_path

  # The paths to look for template files for generators.
  #
  # Defaults to checking the current app's `priv` directory,
  # and falls back to phx_gen_auth's `priv` directory.
  defp generator_paths do
    [".", :phoenix]
  end

  defp inject_before_final_end(content_to_inject, file_path) do
    with {:ok, file} <- read_file(file_path),
         {:ok, new_file} <- Injector.inject_before_final_end(file, content_to_inject) do
      print_injecting(file_path)
      File.write!(file_path, new_file)
    else
      :already_injected ->
        :ok

      {:error, {:file_read_error, _}} ->
        print_injecting(file_path)

        print_unable_to_read_file_error(
          file_path,
          """

          Please add the following to the end of your equivalent
          #{Path.relative_to_cwd(file_path)} module:

          #{indent_spaces(content_to_inject, 2)}
          """
        )
    end
  end

  defp read_file(file_path) do
    case File.read(file_path) do
      {:ok, file} -> {:ok, file}
      {:error, reason} -> {:error, {:file_read_error, reason}}
    end
  end

  defp indent_spaces(string, number_of_spaces) when is_binary(string) and is_integer(number_of_spaces) do
    indent = String.duplicate(" ", number_of_spaces)

    string
    |> String.split("\n")
    |> Enum.map_join("\n", &(indent <> &1))
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp prepend_newline(string) when is_binary(string), do: "\n" <> string

  defp get_ecto_adapter!(%Schema{repo: repo}) do
    if Code.ensure_loaded?(repo) do
      repo.__adapter__()
    else
      Mix.raise("Unable to find #{inspect(repo)}")
    end
  end

  defp print_injecting(file_path, suffix \\ []) do
    Mix.shell().info([:green, "* injecting ", :reset, Path.relative_to_cwd(file_path), suffix])
  end

  defp print_unable_to_read_file_error(file_path, help_text) do
    Mix.shell().error(
      """

      Unable to read file #{Path.relative_to_cwd(file_path)}.

      #{help_text}
      """
      |> indent_spaces(2)
    )
  end

  @doc false
  def raise_with_help(msg) do
    raise_with_help(msg, :general)
  end

  defp raise_with_help(msg, :general) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth expects a context module name, followed by
    the schema module and its plural name (used as the schema
    table name).

    For example:

        mix phx.gen.auth Accounts User users

    The context serves as the API boundary for the given resource.
    Multiple resources may belong to a context and a resource may be
    split over distinct contexts (such as Accounts.User and Payments.User).
    """)
  end

  defp raise_with_help(msg, :phx_generator_args) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth must be installed into a Phoenix 1.5 app that
    contains ecto and html templates.

        mix phx.new my_app
        mix phx.new my_app --umbrella
        mix phx.new my_app --database mysql

    Apps generated with --no-ecto or --no-html are not supported.
    """)
  end

  defp raise_with_help(msg, :hashing_lib) do
    Mix.raise("""
    #{msg}

    mix phx.gen.auth supports the following values for --hashing-lib

      * bcrypt
      * pbkdf2
      * argon2

    Visit https://github.com/riverrun/comeonin for more information
    on choosing a library.
    """)
  end

  defp test_case_options(Ecto.Adapters.Postgres), do: ", async: true"
  defp test_case_options(adapter) when is_atom(adapter), do: ""
end
