Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.DigestTest do
  use ExUnit.Case
  import MixHelper

  test "fails when the given paths are invalid" do
    Mix.Tasks.Phx.Digest.run(["invalid_path", "--no-deps-check"])
    assert_received {:mix_shell, :error, ["The input path \"invalid_path\" does not exist"]}
  end

  @output_path "mix_phoenix_digest"
  test "digests and compress files" do
    in_tmp @output_path, fn ->
      File.mkdir_p!("priv/static")
      Mix.Tasks.Phx.Digest.run(["priv/static", "-o", @output_path, "--no-deps-check"])
      assert_received {:mix_shell, :info, ["Check your digested files at \"mix_phoenix_digest\""]}
    end
  end

  @output_path "mix_phoenix_digest_no_input"
  test "digests and compress files without the input path" do
    in_tmp @output_path, fn ->
      File.mkdir_p!("priv/static")
      Mix.Tasks.Phx.Digest.run(["-o", @output_path, "--no-deps-check"])
      assert_received {:mix_shell, :info, ["Check your digested files at \"mix_phoenix_digest_no_input\""]}
    end
  end

  @input_path "input_path"
  test "uses the input path as output path when no outputh path is given" do
    in_tmp @input_path, fn ->
      File.mkdir_p!(@input_path)
      Mix.Tasks.Phx.Digest.run([@input_path, "--no-deps-check"])
      assert_received {:mix_shell, :info, ["Check your digested files at \"input_path\""]}
    end
  end
end
