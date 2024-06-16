defmodule Mix.Tasks.Phx.Digest.CleanTest do
  use ExUnit.Case

  test "fails when the given paths are invalid" do
    Mix.Tasks.Phx.Digest.Clean.run(["--output", "invalid_path", "--no-compile"])

    assert_received {:mix_shell, :error, ["The output path \"invalid_path\" does not exist"]}
  end

  test "removes old versions", config do
    output_path = Path.join("tmp", to_string(config.test))
    input_path = "priv/static"

    try do
      :ok = File.mkdir_p!(output_path)

      Mix.Tasks.Phx.Digest.Clean.run([input_path, "-o", output_path, "--no-compile"])

      msg = "Clean complete for \"#{output_path}\""
      assert_received {:mix_shell, :info, [^msg]}
    after
      File.rm_rf!(output_path)
    end
  end
end
