Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.PresenceTest do
  use ExUnit.Case
  import MixHelper

  setup do
    Mix.Task.clear()
    :ok
  end

  test "generates presence" do
    in_tmp_project "generates presence", fn ->
      Mix.Tasks.Phx.Gen.Presence.run(["MyPresence"])

      assert_file "lib/web/channels/my_presence.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.MyPresence do|
        assert file =~ ~S|use Phoenix.Presence, otp_app: :phoenix|
      end
    end
  end

  test "passing no args defaults to Presence" do
    in_tmp_project "generates presence", fn ->
      Mix.Tasks.Phx.Gen.Presence.run([])

      assert_file "lib/web/channels/presence.ex", fn file ->
        assert file =~ ~S|defmodule Phoenix.Presence do|
        assert file =~ ~S|use Phoenix.Presence, otp_app: :phoenix|
      end
    end
  end
end
