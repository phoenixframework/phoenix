defmodule Phoenix.Integration.CodeGeneratorCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import unquote(__MODULE__)
    end
  end

  # NOTE: Keep `app_name` short (as of writing, <= 10 characters excluding underscores,
  # e.g. "pg_auth_live", "umb_a_html"). App names are converted to module names, and long names
  # can cause lines in generated files to exceed Elixir's default 98-character formatter limit
  # and fail `assert_passes_formatter_check/1`.
  # Additionally, each concurrent test module must use a unique `app_name` to guarantee test
  # database isolation (`<app_name>_test`) when running against shared database services.
  def generate_phoenix_app(tmp_dir, app_name, opts \\ [])
      when is_binary(app_name) and is_list(opts) do
    app_path = Path.expand(app_name, tmp_dir)
    integration_test_root_path = Path.expand("../../", __DIR__)
    app_root_path = get_app_root_path(tmp_dir, app_name, opts)

    output =
      mix_run!(["phx.new", app_path, "--dev", "--no-install"] ++ opts, integration_test_root_path)

    for path <- ~w(mix.lock deps _build) do
      File.cp_r!(
        Path.join(integration_test_root_path, path),
        Path.join(app_root_path, path)
      )
    end

    {app_root_path, output}
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

      is_binary(match) or is_struct(match, Regex) ->
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

  # Renames existing migration files in `app_path` to deterministic, sequentially ordered
  # timestamps in the past (starting at 2000-01-01 00:00:00).
  #
  # Consecutive generator invocations in tests (e.g. `phx.gen.auth` followed by `phx.gen.live`)
  # run fast enough to generate migrations within the same second, leading to timestamp
  # collisions or unexpected execution order. Calling this helper between generator runs
  # shifts existing migrations to earlier timestamps so subsequent generators can produce
  # fresh, non-colliding migration versions with current timestamps immediately without sleeping.
  #
  # Preconditions & Limitations:
  #
  # - Must be called before migrations are executed against the database.
  # - Only looks for migrations under `priv/repo/migrations`.
  def adjust_migration_timestamps(app_path) when is_binary(app_path) do
    [
      Path.join(app_path, "priv/repo/migrations/*_*.exs"),
      Path.join(app_path, "apps/*/priv/repo/migrations/*_*.exs")
    ]
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.with_index()
    |> Enum.each(fn {path, idx} ->
      dir = Path.dirname(path)
      name = Path.basename(path)
      [_, rest] = Regex.run(~r"^\d{14}_(.+)$", name)
      new_timestamp = Integer.to_string(20_000_101_000_000 + idx)
      new_path = Path.join(dir, "#{new_timestamp}_#{rest}")

      if path != new_path do
        File.rename!(path, new_path)
      end
    end)
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
end
