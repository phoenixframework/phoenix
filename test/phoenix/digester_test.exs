defmodule Phoenix.DigesterTest do
  use ExUnit.Case, async: true

  test "fails when the given paths are invalid" do
    assert {:error, :invalid_path} = Phoenix.Digester.compile("nonexistent path", "/ ?? /path")
  end

  test "digests and compress files" do
    output_path = Path.join("tmp", "phoenix_digest")
    input_path  = "test/fixtures/digest/priv/static/"

    File.rm_rf!(output_path)
    assert :ok = Phoenix.Digester.compile(input_path, output_path)

    output_files = assets_files(output_path)

    assert "phoenix.png" in output_files
    refute "phoenix.png.gz" in output_files
    assert "app.js" in output_files
    assert "app.js.gz" in output_files
    assert "css/app.css" in output_files
    assert "css/app.css.gz" in output_files
    assert "manifest.json" in output_files
    assert Enum.any?(output_files, &(String.match?(&1, ~r/(phoenix-[a-fA-F\d]{32}\.png)/)))
    refute Enum.any?(output_files, &(String.match?(&1, ~r/(phoenix-[a-fA-F\d]{32}\.png\.gz)/)))

    json =
      Path.join(output_path, "manifest.json")
      |> File.read!()
      |> Poison.decode!()
    assert json["phoenix.png"] =~ ~r"phoenix-[a-fA-F\d]{32}.png"
  end

  test "digests and compress nested files" do
    output_path = Path.join("tmp", "phoenix_digest_nested")
    input_path  = "test/fixtures/digest/priv/"

    File.rm_rf!(output_path)
    assert :ok = Phoenix.Digester.compile(input_path, output_path)

    output_files = assets_files(output_path)

    assert "static/phoenix.png" in output_files
    refute "static/phoenix.png.gz" in output_files
    assert "manifest.json" in output_files
    assert Enum.any?(output_files, &(String.match?(&1, ~r/(phoenix-[a-fA-F\d]{32}\.png)/)))
    refute Enum.any?(output_files, &(String.match?(&1, ~r/(phoenix-[a-fA-F\d]{32}\.png\.gz)/)))

    json =
      Path.join(output_path, "manifest.json")
      |> File.read!()
      |> Poison.decode!()
    assert json["static/phoenix.png"] =~ ~r"static/phoenix-[a-fA-F\d]{32}\.png"
  end

  test "doesn't duplicate files when digesting and compressing twice" do
    input_path = Path.join("tmp", "phoenix_digest_twice")
    input_file = Path.join(input_path, "file.js")

    File.rm_rf!(input_path)
    File.mkdir_p!(input_path)
    File.write!(input_file, "console.log('test');")

    assert :ok = Phoenix.Digester.compile(input_path, input_path)
    assert :ok = Phoenix.Digester.compile(input_path, input_path)

    output_files = assets_files(input_path)

    refute "file.js.gz.gz" in output_files
    refute "manifest.json.gz" in output_files
    refute Enum.any?(output_files, & &1 =~ ~r/file-[a-fA-F\d]{32}.[\w|\d]*.[-[a-fA-F\d]{32}/)
  end

  test "digests only absolute and relative asset paths found within stylesheets" do
    output_path = Path.join("tmp", "phoenix_digest_stylesheets")
    input_path  = "test/fixtures/digest/priv/static/"

    File.rm_rf!(output_path)
    assert :ok = Phoenix.Digester.compile(input_path, output_path)

    digested_css_filename =
      assets_files(output_path)
      |> Enum.find(&(&1 =~ ~r"app-[a-fA-F\d]{32}.css"))

    digested_css =
      Path.join(output_path, digested_css_filename)
      |> File.read!()

    refute digested_css =~ ~r"/phoenix\.png"
    refute digested_css =~ ~r"\.\./images/relative\.png"
    assert digested_css =~ ~r"/phoenix-[a-fA-F\d]{32}\.png\?vsn=d"
    assert digested_css =~ ~r"\.\./images/relative-[a-fA-F\d]{32}\.png\?vsn=d"

    refute digested_css =~ ~r"http://www.phoenixframework.org/absolute-[a-fA-F\d]{32}.png"
    assert digested_css =~ ~r"http://www.phoenixframework.org/absolute.png"
  end

  test "does not digest assets within undigested files" do
    output_path = Path.join("tmp", "phoenix_digest_stylesheets_undigested")
    input_path  = "test/fixtures/digest/priv/static/"

    File.rm_rf!(output_path)
    assert :ok = Phoenix.Digester.compile(input_path, output_path)

    undigested_css =
      Path.join(output_path, "css/app.css")
      |> File.read!()

    assert undigested_css =~ ~r"/phoenix\.png"
    assert undigested_css =~ ~r"\.\./images/relative\.png"
    refute undigested_css =~ ~r"/phoenix-[a-fA-F\d]{32}\.png"
    refute undigested_css =~ ~r"\.\./images/relative-[a-fA-F\d]{32}\.png"
  end

  defp assets_files(path) do
    path
    |> Path.join("**/*")
    |> Path.wildcard
    |> Enum.filter(&(!File.dir?(&1)))
    |> Enum.map(&(Path.relative_to(&1, path)))
  end
end
