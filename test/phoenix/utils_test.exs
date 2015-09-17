defmodule Phoenix.UtilsTest do
  use ExUnit.Case, async: true

  test "now_ms/0" do
    assert Phoenix.Utils.now_ms()
  end
end
