# Get Mix output sent to the current
# process to avoid polluting tests.
Mix.shell(Mix.Shell.Process)

defmodule MixHelper do
  import ExUnit.Assertions
  import ExUnit.CaptureIO

  def tmp_path do
    Path.expand("../../tmp", __DIR__)
  end

  defp random_string(len) do
    len |> :crypto.strong_rand_bytes() |> Base.url_encode64() |> binary_part(0, len)
  end

  def in_tmp(which, function) do
    base = Path.join([tmp_path(), random_string(10)])
    path = Path.join([base, to_string(which)])

    try do
      File.rm_rf!(path)
      File.mkdir_p!(path)
      File.cd!(path, function)
    after
      File.rm_rf!(base)
    end
  end

  def in_tmp_project(which, function) do
    base = Path.join([tmp_path(), random_string(10)])
    path = Path.join([base, to_string(which)])

    try do
      File.rm_rf!(path)
      File.mkdir_p!(path)

      File.cd!(path, fn ->
        File.touch!("mix.exs")
        with_generator_env([format_extensions: []], function)
      end)
    after
      File.rm_rf!(base)
    end
  end

  def in_tmp_umbrella_project(which, function) do
    base = Path.join([tmp_path(), random_string(10)])
    path = Path.join([base, to_string(which)])

    try do
      apps_path = Path.join(path, "apps")
      config_path = Path.join(path, "config")
      File.rm_rf!(path)
      File.mkdir_p!(path)
      File.mkdir_p!(apps_path)
      File.mkdir_p!(config_path)
      File.touch!(Path.join(path, "mix.exs"))

      for file <- ~w(config.exs dev.exs test.exs prod.exs) do
        File.write!(Path.join(config_path, file), "import Config\n")
      end

      File.cd!(apps_path, fn ->
        with_generator_env([format_extensions: []], function)
      end)
    after
      File.rm_rf!(base)
    end
  end

  def in_project(app, path, fun) do
    %{name: name, file: file} = Mix.Project.pop()

    try do
      capture_io(:stderr, fn ->
        Mix.Project.in_project(app, path, [prune_code_paths: false], fn mod ->
          fun.(mod)
          Mix.Project.clear_deps_cache()
        end)
      end)
    after
      Mix.Project.push(name, file)
    end
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

  def modify_file(path, function) when is_binary(path) and is_function(function, 1) do
    path
    |> File.read!()
    |> function.()
    |> write_file!(path)
  end

  defp write_file!(content, path) do
    File.write!(path, content)
  end

  def with_generator_env(app_name \\ :phoenix, new_env, fun) do
    config_before = Application.get_env(app_name, :generators)
    Application.put_env(app_name, :generators, Keyword.merge(config_before || [], new_env))

    try do
      fun.()
    after
      case config_before do
        nil -> Application.delete_env(app_name, :generators)
        config -> Application.put_env(app_name, :generators, config)
      end
    end
  end

  def umbrella_mixfile_contents do
    """
    defmodule Umbrella.MixProject do
      use Mix.Project

      def project do
        [
          apps_path: "apps",
          deps: deps()
        ]
      end

      defp deps do
        []
      end
    end
    """
  end

  def flush do
    receive do
      _ -> flush()
    after
      0 -> :ok
    end
  end
end
