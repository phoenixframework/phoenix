defmodule Mix.Tasks.Phx.Gen.Notifier do
  @shortdoc "Generates a notifier that delivers emails by default"

  @moduledoc """
  Generates a notifier that delivers emails by default.

      $ mix phx.gen.notifier Accounts User welcome_user reset_password confirmation_instructions

  This task expects a context module name, followed by a
  notifier name and one or more message names. Messages
  are the functions that will be created prefixed by "deliver",
  so the message name should be "snake_case" without punctuation.

  Additionally a context app can be specified with the flag
  `--context-app`, which is useful if the notifier is being
  generated in a different app under an umbrella.

      $ mix phx.gen.notifier Accounts User welcome_user --context-app marketing

  The app "marketing" must exist before the command is executed.
  """

  use Mix.Task

  @switches [
    context: :boolean,
    context_app: :string,
    prefix: :string
  ]

  @default_opts [context: true]

  alias Mix.Phoenix.Context

  @doc false
  def run(args) do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.notifier must be invoked from within your *_web application root directory"
      )
    end

    {context, notifier_module, messages} = build(args)

    inflections = Mix.Phoenix.inflect(notifier_module)

    binding = [
      context: context,
      inflections: inflections,
      notifier_messages: messages
    ]

    paths = Mix.Phoenix.generator_paths()

    prompt_for_conflicts(context)

    if "--no-compile" not in args do
      Mix.Task.run("compile")
    end

    context
    |> copy_new_files(binding, paths)
    |> maybe_print_mailer_installation_instructions()
  end

  @doc false
  def build(args, help \\ __MODULE__) do
    {opts, parsed, _} = parse_opts(args)

    [context_name, notifier_name | notifier_messages] = validate_args!(parsed, help)

    notifier_module = inspect(Module.concat(context_name, "#{notifier_name}Notifier"))
    context = Context.new(notifier_module, opts)

    {context, notifier_module, notifier_messages}
  end

  defp parse_opts(args) do
    {opts, parsed, invalid} = OptionParser.parse(args, switches: @switches)

    merged_opts =
      @default_opts
      |> Keyword.merge(opts)
      |> put_context_app(opts[:context_app])

    {merged_opts, parsed, invalid}
  end

  defp put_context_app(opts, nil), do: opts

  defp put_context_app(opts, string) do
    Keyword.put(opts, :context_app, String.to_atom(string))
  end

  defp validate_args!([context, notifier | messages] = args, help) do
    cond do
      not Context.valid?(context) ->
        help.raise_with_help(
          "Expected the context, #{inspect(context)}, to be a valid module name"
        )

      not valid_notifier?(notifier) ->
        help.raise_with_help(
          "Expected the notifier, #{inspect(notifier)}, to be a valid module name"
        )

      context == Mix.Phoenix.base() ->
        help.raise_with_help(
          "Cannot generate context #{context} because it has the same name as the application"
        )

      notifier == Mix.Phoenix.base() ->
        help.raise_with_help(
          "Cannot generate notifier #{notifier} because it has the same name as the application"
        )

      Enum.any?(messages, &(!valid_message?(&1))) ->
        help.raise_with_help(
          "Cannot generate notifier #{inspect(notifier)} because one of the messages is invalid: #{Enum.map_join(messages, ", ", &inspect/1)}"
        )

      true ->
        args
    end
  end

  defp validate_args!(_, help) do
    help.raise_with_help("Invalid arguments")
  end

  defp valid_notifier?(notifier) do
    notifier =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/
  end

  defp valid_message?(message_name) do
    message_name =~ ~r/^[a-z]+(\_[a-z0-9]+)*$/
  end

  @doc false
  @spec raise_with_help(String.t()) :: no_return()
  def raise_with_help(msg) do
    Mix.raise("""
    #{msg}

    mix phx.gen.notifier expects a context module name, followed by a
    notifier name and one or more message names. Messages are the
    functions that will be created prefixed by "deliver", so the message
    name should be "snake_case" without punctuation.
    For example:

        mix phx.gen.notifier Accounts User welcome reset_password

    In this example the notifier will be called `UserNotifier` inside
    the Accounts context. The functions `deliver_welcome/1` and
    `reset_password/1` will be created inside this notifier.
    """)
  end

  defp copy_new_files(%Context{} = context, binding, paths) do
    files = files_to_be_generated(context)

    Mix.Phoenix.copy_from(paths, "priv/templates/phx.gen.notifier", binding, files)

    context
  end

  defp files_to_be_generated(%Context{} = context) do
    [
      {:eex, "notifier.ex", context.file},
      {:eex, "notifier_test.exs", context.test_file}
    ]
  end

  defp prompt_for_conflicts(context) do
    context
    |> files_to_be_generated()
    |> Mix.Phoenix.prompt_for_conflicts()
  end

  @doc """
  Print mailer instructions if mailer is not defined.

  This is useful for applications that were created without the
  mailer.
  """
  @spec maybe_print_mailer_installation_instructions(%Context{}) :: %Context{}
  def maybe_print_mailer_installation_instructions(%Context{} = context) do
    mailer_module = Module.concat([context.base_module, "Mailer"])

    unless Code.ensure_loaded?(mailer_module) do
      Mix.shell().info("""
      Unable to find the "#{inspect(mailer_module)}" module defined.

      A mailer module like the following is expected to be defined
      in your application in order to send emails.

          defmodule #{inspect(mailer_module)} do
            use Swoosh.Mailer, otp_app: #{inspect(context.context_app)}
          end

      It is also necessary to add "swoosh" as a dependency in your
      "mix.exs" file:

          def deps do
            [{:swoosh, "~> 1.4"}]
          end

      Finally, an adapter needs to be set in your configuration:

          import Config
          config #{inspect(context.context_app)}, #{inspect(mailer_module)}, adapter: Swoosh.Adapters.Local

      Check https://hexdocs.pm/swoosh for more details.
      """)
    end

    context
  end
end
