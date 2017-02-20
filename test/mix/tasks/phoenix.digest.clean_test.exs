defmodule Mix.Tasks.Phoenix.Digest.CleanTest do
  use ExUnit.Case

  test "fails when the given paths are invalid" do
    Mix.Tasks.Phoenix.Digest.Clean.run(["--output", "invalid_path"])

    assert_received {:mix_shell, :error, ["The output path \"invalid_path\" does not exist"]}
  end

  test "removes old versions" do
    output_path = Path.join("tmp", "mix_phoenix_digest")
    input_path = "priv/static"
    :ok = File.mkdir_p!(output_path)

    Mix.Tasks.Phoenix.Digest.Clean.run([input_path, "-o", output_path])

    assert_received {:mix_shell, :info, ["Clean complete for \"tmp/mix_phoenix_digest\""]}
  end
end
