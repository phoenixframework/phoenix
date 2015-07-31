Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.Gen.SecretTest do
  use ExUnit.Case, async: true

  import Mix.Tasks.Phoenix.Gen.Secret

  test "generates a secret" do
    run []
    assert_receive {:mix_shell, :info, [secret]} when byte_size(secret) == 64
  end

  test "generates a secret with custom length" do
    run ["32"]
    assert_receive {:mix_shell, :info, [secret]} when byte_size(secret) == 32
  end

  test "raises on invalid args" do
    message = "mix phoenix.gen.secret expects a length as integer or no argument at all"
    assert_raise Mix.Error, message, fn -> run ["bad"] end
    assert_raise Mix.Error, message, fn -> run ["32bad"] end
    assert_raise Mix.Error, message, fn -> run ["32", "bad"] end
  end
end
