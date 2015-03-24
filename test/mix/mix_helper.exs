# Mock live reload dependency.
defmodule Phoenix.LiveReloader do
  def init(opts), do: opts
  def call(conn, _), do: conn
end

defmodule Mix.RouterTest do
  use Phoenix.Router
  get "/", PageController, :index, as: :page
end

defmodule MixHelper do
  import ExUnit.Assertions

  def tmp_path do
    Path.expand("../../tmp", __DIR__)
  end

  def in_tmp(which, function) do
    path = Path.join(tmp_path, which)
    File.rm_rf! path
    File.mkdir_p! path
    File.cd! path, function
  end

  def assert_file(file) do
    assert File.regular?(file), "Expected #{file} to exist, but does not"
  end

  def assert_file(file, match) do
    cond do
      Regex.regex?(match) ->
        assert_file file, &(assert &1 =~ match)
      is_function(match, 1) ->
        assert_file(file)
        match.(File.read!(file))
    end
  end
end