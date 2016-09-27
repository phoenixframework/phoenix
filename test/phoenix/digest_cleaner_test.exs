defmodule Phoenix.DigestCleanerTest do
  use ExUnit.Case, async: true

  @fake_now 32132173

  test "fails when the given path is invalid" do
    assert {:error, :invalid_path} = Phoenix.DigestCleaner.clean("nonexistent path", 3600, 2)
  end

  test "removes versions over the keep count" do
    manifest_path = "test/fixtures/digest/cleaner/manifest.json"
    output_path = Path.join("tmp", "phoenix_digest_cleaner")
    File.rm_rf!(output_path)

    File.mkdir(output_path)
    File.cp(manifest_path, "#{output_path}/manifest.json")
    File.touch("#{output_path}/app.css")
    File.touch("#{output_path}/app-1.css")
    File.touch("#{output_path}/app-1.css.gz")
    File.touch("#{output_path}/app-2.css")
    File.touch("#{output_path}/app-2.css.gz")
    File.touch("#{output_path}/app-3.css")
    File.touch("#{output_path}/app-3.css.gz")
    File.touch("#{output_path}/app.css")
    assert :ok = Phoenix.DigestCleaner.clean(output_path, 3600, 1, @fake_now)

    output_files = assets_files(output_path)

    assert "app.css" in output_files
    assert "app-3.css" in output_files
    assert "app-3.css.gz" in output_files
    assert "app-2.css" in output_files
    assert "app-2.css.gz" in output_files
    refute "app-1.css" in output_files
    refute "app-1.css.gz" in output_files
  end

  test "removes files older than specified number of seconds" do
    manifest_path = "test/fixtures/digest/cleaner/manifest.json"
    output_path = Path.join("tmp", "phoenix_digest_cleaner")
    File.rm_rf!(output_path)

    File.mkdir(output_path)
    File.cp(manifest_path, "#{output_path}/manifest.json")
    File.touch("#{output_path}/app.css")
    File.touch("#{output_path}/app-1.css")
    File.touch("#{output_path}/app-1.css.gz")
    File.touch("#{output_path}/app-2.css")
    File.touch("#{output_path}/app-2.css.gz")
    File.touch("#{output_path}/app-3.css")
    File.touch("#{output_path}/app-3.css.gz")
    File.touch("#{output_path}/app.css")
    assert :ok = Phoenix.DigestCleaner.clean(output_path, 1, 10, @fake_now)

    output_files = assets_files(output_path)

    assert "app.css" in output_files
    assert "app-2.css" in output_files
    assert "app-2.css.gz" in output_files
    assert "app-3.css" in output_files
    assert "app-3.css.gz" in output_files
    refute "app-1.css" in output_files
    refute "app-1.css.gz" in output_files
  end

  defp assets_files(path) do
    path
    |> Path.join("**/*")
    |> Path.wildcard
    |> Enum.filter(&(!File.dir?(&1)))
    |> Enum.map(&(Path.relative_to(&1, path)))
  end
end
