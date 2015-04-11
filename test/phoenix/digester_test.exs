defmodule Phoenix.DigesterTest do
  use ExUnit.Case, async: true

  test "fails when the given paths are invalid" do
    assert {:error, :invalid_path} = Phoenix.Digester.compile("inexistent path", "/ ?? /path")
  end

  test "digests and compress files" do
    output_path = Path.join("tmp", "phoenix_digest")
    input_path = "priv/static/"

    assert :ok = Phoenix.Digester.compile(input_path, output_path)

    output_files = assets_files(output_path)

    assert Enum.member?(output_files, "phoenix.png.gz")
    assert Enum.member?(output_files, "phoenix.png")
    assert Enum.member?(output_files, "manifest.json")
    assert Enum.any?(output_files, &(String.match?(&1, ~r/(phoenix-[a-fA-F\d]{32}.png)/)))
    assert Enum.any?(output_files, &(String.match?(&1, ~r/(phoenix-[a-fA-F\d]{32}.png.gz)/)))
  end

  test "doesn't duplicate files when digesting and compressing twice" do
    input_path = Path.join("tmp", "phoenix_digest_twice")
    input_file = Path.join(input_path, "file.js")
    File.mkdir_p!(input_path)
    File.write!(input_file, "console.log('test');")

    assert :ok = Phoenix.Digester.compile(input_path, input_path)
    assert :ok = Phoenix.Digester.compile(input_path, input_path)

    output_files = assets_files(input_path)

    duplicated_digested_file_regex = ~r/(file-[a-fA-F\d]{32}.[\w|\d]*.[-[a-fA-F\d]{32})/
    assert Enum.any?(output_files, fn (f) ->
      !String.match?(f, duplicated_digested_file_regex)
        !String.match?(f, ~r/(file.js.gz.gz)/)
    end)
  end

  defp assets_files(path) do
    path
    |> Path.join("**")
    |> Path.wildcard
    |> Enum.filter(&(!File.dir?(&1)))
    |> Enum.map(&(Path.basename(&1)))
  end
end
