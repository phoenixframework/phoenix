Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.SecretTest do
  use ExUnit.Case
  import Mix.Tasks.Phx.Gen.Secret

  describe "secret generation" do
    test "generates a default secret with 64 bytes" do
      run []
      assert_receive {:mix_shell, :info, [secret]} when byte_size(secret) == 64
      assert String.printable?(secret), "Generated secret contains non-printable characters"
    end

    test "generates a secret with custom length" do
      run ["32"]
      assert_receive {:mix_shell, :info, [secret]} when byte_size(secret) == 32
      assert String.printable?(secret), "Generated secret with custom length contains non-printable characters"
    end
  end

  describe "argument validation" do
    test "raises error on invalid arguments" do
      message = "mix phx.gen.secret expects a length as integer or no argument at all"
      
      invalid_args = [["bad"], ["32bad"], ["32", "bad"]]
      
      for args <- invalid_args do
        assert_raise Mix.Error, message, fn -> run(args) end
      end
    end

    test "raises error when length is too short" do
      message = "The secret should be at least 32 characters long"
      
      short_lengths = ["0", "31"]
      
      for length <- short_lengths do
        assert_raise Mix.Error, message, fn -> run([length]) end
      end
    end
  end
end
