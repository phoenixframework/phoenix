Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phoenix.Gen.PresenceTest do
  use ExUnit.Case
  import MixHelper
  import ExUnit.CaptureIO

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates presence" do
    in_tmp "deprecated: generates presence", fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Presence.run(["MyPresence"])
      end)

      assert_file "web/channels/my_presence.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.MyPresence do|
        assert file =~ ~S|use Phoenix.Presence, otp_app: :phoenix|
      end
    end
  end

  test "passing no args defaults to Presence" do
    in_tmp "deprecated: generates presence", fn ->
      capture_io(:stderr, fn ->
        Mix.Tasks.Phoenix.Gen.Presence.run([])
      end)

      assert_file "web/channels/presence.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Presence do|
        assert file =~ ~S|use Phoenix.Presence, otp_app: :phoenix|
      end
    end
  end
end
