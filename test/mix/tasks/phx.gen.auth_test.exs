Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Mix.Tasks.Phx.Gen.AuthTest do
  use ExUnit.Case

  import MixHelper
  alias Mix.Tasks.Phx.Gen

  setup do
    Mix.Task.clear()
    :ok
  end

  test "invalid mix arguments", config do
    in_tmp_project(config.test, fn ->
      assert_raise Mix.Error, ~r/Expected the context, "accounts", to be a valid module name.*phx\.gen\.auth/s, fn ->
        Gen.Auth.run(~w(accounts User users))
      end

      assert_raise Mix.Error, ~r/Expected the schema, "user", to be a valid module name/, fn ->
        Gen.Auth.run(~w(Accounts user users))
      end

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Gen.Auth.run(~w(User User users))
      end

      assert_raise Mix.Error, ~r/Cannot generate context Phoenix because it has the same name as the application/, fn ->
        Gen.Auth.run(~w(Phoenix User users))
      end

      assert_raise Mix.Error, ~r/Cannot generate schema Phoenix because it has the same name as the application/, fn ->
        Gen.Auth.run(~w(Accounts Phoenix users))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Auth.run(~w())
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Auth.run(~w(Accounts))
      end

      assert_raise Mix.Error, ~r/Invalid arguments.*phx\.gen\.auth/s, fn ->
        Gen.Auth.run(~w(Accounts User users name:string))
      end

      assert_raise OptionParser.ParseError, ~r/unknown option/i, fn ->
        Gen.Auth.run(~w(Accounts User users --no-schema))
      end

      assert_raise Mix.Error, ~r/Unknown value for --hashing-lib/, fn ->
        Gen.Auth.run(~w(Accounts User users --hashing-lib unknown))
      end
    end)
  end
end
