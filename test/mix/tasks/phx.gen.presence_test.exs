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

      assert_file "lib/phoenix_web/channels/my_presence.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.MyPresence do|
        assert file =~ ~S|use Phoenix.Presence, otp_app: :phoenix|
      end
    end
  end

  test "passing no args defaults to Presence" do
    in_tmp_project "generates presence", fn ->
      Mix.Tasks.Phx.Gen.Presence.run([])

      assert_file "lib/phoenix_web/channels/presence.ex", fn file ->
        assert file =~ ~S|defmodule PhoenixWeb.Presence do|
        assert file =~ ~S|use Phoenix.Presence, otp_app: :phoenix|
      end
    end
  end

  test "in an umbrella with a context_app, the file goes in lib/app/channels" do
    in_tmp_umbrella_project "generates presences", fn ->
      Application.put_env(:phoenix, :generators, context_app: {:another_app, "another_app"})
      Mix.Tasks.Phx.Gen.Presence.run([])
      assert_file "lib/phoenix/channels/presence.ex"
    end
  end
end
