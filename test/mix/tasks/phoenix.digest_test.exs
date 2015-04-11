defmodule Mix.Tasks.Phoenix.DigestTest do
  use ExUnit.Case, async: true

  test "fails when the given paths are invalid" do
    assert_raise Mix.Error, "The input path 'invalid_path' does not exist.", fn ->
      Mix.Tasks.Phoenix.Digest.run(["invalid_path"])
    end
  end

  test "digests and compress files" do
    output_path = Path.join("tmp", "digested")
    input_path = "priv/static"

    File.mkdir_p!(output_path)

    Mix.Tasks.Phoenix.Digest.run([input_path, "-o", output_path])
    assert_received {:mix_shell, :info, ["Check your digested files at 'tmp/digested'."]}
  end

  test "uses the input path as output path when no outputh path is given" do
    input_path = Path.join("tmp", "input_path")
    File.mkdir_p!(input_path)

    Mix.Tasks.Phoenix.Digest.run([input_path])
    assert_received {:mix_shell, :info, ["Check your digested files at 'tmp/input_path'."]}
  end
end
