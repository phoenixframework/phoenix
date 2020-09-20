Code.require_file("./mix_task_runner.exs", __DIR__)

defmodule Phoenix.Integration.CodeGeneratorCase do
  use ExUnit.CaseTemplate

  alias Phoenix.Integration.MixTaskRunner

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def generate_phoenix_app(tmp_dir, app_name, opts \\ [])
      when is_binary(app_name) and is_list(opts) do
    app_path = Path.expand(app_name, tmp_dir)
    installer_root = Path.expand("../../installer", __DIR__)
    app_root_path = get_app_root_path(tmp_dir, app_name, opts)

    MixTaskRunner.run!(["phx.new", app_path, "--dev"] ++ opts,
      cd: installer_root,
      prompt_responses: :no_to_all
    )

    MixTaskRunner.run!(~w(deps.get), cd: app_root_path)

    app_root_path
  end

  def mix_deps_get(app_path) do
    MixTaskRunner.run!(~w(deps.get), cd: app_path)
  end

  def mix_run!(app_path, args) when is_list(args) do
    MixTaskRunner.run!(args, cd: app_path)
  end

  def assert_passes_formatter_check(app_path) do
    MixTaskRunner.run!(~w(format --check-formatted), cd: app_path)
  end

  def assert_no_compilation_warnings(app_path) do
    MixTaskRunner.run!(["do", "clean,", "compile", "--warnings-as-errors"], cd: app_path)
  end

  def with_installer_tmp(name, opts \\ [], function)
      when is_list(opts) and is_function(function, 1) do
    autoremove? = Keyword.get(opts, :autoremove?, true)
    path = Path.join([installer_tmp_path(), random_string(10), to_string(name)])

    try do
      File.rm_rf!(path)
      File.mkdir_p!(path)
      function.(path)
    after
      if autoremove?, do: File.rm_rf!(path)
    end
  end

  defp installer_tmp_path do
    Path.expand("../../installer/tmp", __DIR__)
  end

  defp get_app_root_path(tmp_dir, app_name, opts) do
    app_root_dir =
      if "--umbrella" in opts do
        app_name <> "_umbrella"
      else
        app_name
      end

    Path.expand(app_root_dir, tmp_dir)
  end

  defp random_string(len) do
    len |> :crypto.strong_rand_bytes() |> Base.encode64() |> binary_part(0, len)
  end
end
