defmodule Phoenix.Integration.CodeGeneratorCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  def generate_phoenix_app(tmp_dir, app_name, args \\ [], opts \\ [])
      when is_binary(app_name) and is_list(args) and is_list(opts) do
    app_path = Path.expand(app_name, tmp_dir)
    integration_test_root_path = Path.expand("../../", __DIR__)
    app_root_path = get_app_root_path(tmp_dir, app_name, args)

    output =
      mix_run!(["phx.new", app_path, "--dev", "--no-install"] ++ args, integration_test_root_path)

    for path <- ~w(mix.lock deps _build) do
      File.cp_r!(
        Path.join(integration_test_root_path, path),
        Path.join(app_root_path, path)
      )
    end

    # The integration test app has dependencies needed for all apps. This
    # removes all dependencies that aren't needed by this generated app.
    unless opts[:skip_clean_unused_deps] do
      clean_unused_deps(app_root_path)
    end

    {app_root_path, output}
  end

  def clean_unused_deps(app_root_path) do
    mix_run!(["do", "deps.unlock", "--unused,", "deps.clean", "--unused"], app_root_path)
  end

  def mix_run!(args, app_path, opts \\ [])
      when is_list(args) and is_binary(app_path) and is_list(opts) do
    case mix_run(args, app_path, opts) do
      {output, 0} ->
        output

      {output, exit_code} ->
        raise """
        mix command failed with exit code: #{inspect(exit_code)}

        mix #{Enum.join(args, " ")}

        #{output}

        Options
        cd: #{Path.expand(app_path)}
        env: #{opts |> Keyword.get(:env, []) |> inspect()}
        """
    end
  end

  def mix_run(args, app_path, opts \\ [])
      when is_list(args) and is_binary(app_path) and is_list(opts) do
    System.cmd("mix", args, [stderr_to_stdout: true, cd: Path.expand(app_path)] ++ opts)
  end

  def assert_dir(path) do
    assert File.dir?(path), "Expected #{path} to be a directory, but is not"
  end

  def assert_file(file) do
    assert File.regular?(file), "Expected #{file} to exist, but does not"
  end

  def refute_file(file) do
    refute File.regular?(file), "Expected #{file} to not exist, but it does"
  end

  def assert_file(file, match) do
    cond do
      is_list(match) ->
        assert_file(file, &Enum.each(match, fn m -> assert &1 =~ m end))

      is_binary(match) or Regex.regex?(match) ->
        assert_file(file, &assert(&1 =~ match))

      is_function(match, 1) ->
        assert_file(file)
        match.(File.read!(file))

      true ->
        raise inspect({file, match})
    end
  end

  def assert_tests_pass(app_path) do
    mix_run!(~w(test), app_path)
  end

  def assert_passes_formatter_check(app_path) do
    mix_run!(~w(format --check-formatted), app_path)
  end

  def assert_no_compilation_warnings(app_path) do
    mix_run!(["do", "clean,", "compile", "--warnings-as-errors"], app_path)
  end

  def drop_test_database(app_path) when is_binary(app_path) do
    mix_run!(["ecto.drop"], app_path, env: [{"MIX_ENV", "test"}])
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
    Path.expand("../../../installer/tmp", __DIR__)
  end

  def inject_before_final_end(code, code_to_inject)
      when is_binary(code) and is_binary(code_to_inject) do
    code
    |> String.trim_trailing()
    |> String.trim_trailing("end")
    |> Kernel.<>(code_to_inject)
    |> Kernel.<>("end\n")
  end

  def modify_file(path, function) when is_binary(path) and is_function(function, 1) do
    path
    |> File.read!()
    |> function.()
    |> write_file!(path)
  end

  defp write_file!(content, path) do
    File.write!(path, content)
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
    len |> :crypto.strong_rand_bytes() |> Base.url_encode64() |> binary_part(0, len)
  end

  @spec mix_dependency_inject(String.t(), String.t()) ::
          {:ok, String.t()} | :already_injected | {:error, :unable_to_inject}
  def mix_dependency_inject(mixfile, dependency) do
    with :ok <- ensure_not_already_injected(mixfile, dependency),
         {:ok, new_mixfile} <- do_mix_dependency_inject(mixfile, dependency) do
      {:ok, new_mixfile}
    end
  end

  @spec do_mix_dependency_inject(String.t(), String.t()) ::
          {:ok, String.t()} | {:error, :unable_to_inject}
  defp do_mix_dependency_inject(mixfile, dependency) do
    string_to_split_on = """
      defp deps do
        [
    """

    case split_with_self(mixfile, string_to_split_on) do
      {beginning, splitter, rest} ->
        new_mixfile =
          IO.iodata_to_binary([beginning, splitter, "      ", dependency, ?,, ?\n, rest])

        {:ok, new_mixfile}

      _ ->
        {:error, :unable_to_inject}
    end
  end

  @spec ensure_not_already_injected(String.t(), String.t()) :: :ok | :already_injected
  defp ensure_not_already_injected(file, inject) do
    if String.contains?(file, inject) do
      :already_injected
    else
      :ok
    end
  end

  @spec split_with_self(String.t(), String.t()) :: {String.t(), String.t(), String.t()} | :error
  defp split_with_self(contents, text) do
    case :binary.split(contents, text) do
      [left, right] -> {left, text, right}
      [_] -> :error
    end
  end
end
