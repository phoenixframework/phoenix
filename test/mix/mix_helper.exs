defmodule MixHelper do
  import ExUnit.Assertions

  def tmp_path do
    Path.expand("../../tmp", __DIR__)
  end

  def assert_file(file) do
    assert File.regular?(file), "Expected #{file} to exist, but does not"
  end

  def assert_file(file, match) do
    cond do
      Regex.regex?(match) ->
        assert_file file, &(&1 =~ match)
      is_function(match, 1) ->
        assert_file(file)
        match.(File.read!(file))
    end
  end
end