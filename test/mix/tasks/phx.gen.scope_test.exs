Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.Gen.ScopeTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "defaults", config do
    in_tmp_project(config.test, fn ->
      Gen.Scope.run([])

      assert_file("lib/phoenix/scope.ex", fn file ->
        assert file =~ "defmodule Phoenix.Scope do"
      end)

      assert_file("lib/phoenix_web/scope_hook.ex", fn file ->
        assert file =~ "defmodule PhoenixWeb.ScopeHook do"
      end)
    end)
  end
end
