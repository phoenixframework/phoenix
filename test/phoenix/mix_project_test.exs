defmodule Phoenix.MixProjectTest do
  use ExUnit.Case, async: true

  test "version should be valid" do
   assert {:ok, _} = Version.parse(Mix.Project.config()[:version])
  end

  test "revision" do
    case Mix.Project.config()[:revision] do
      "" -> assert true
      <<_::8*7>> -> assert true
      revision -> flunk("Expected as a revision either an empty or a seven-char long string, got: #{inspect(revision)}")
    end
  end
end
