defmodule Phoenix.CodeReloaderTest do
  use ExUnit.Case, async: true
  use ConnHelper

  test "touch/0 touches and returns touched files" do
    assert Phoenix.CodeReloader.touch == []
  end

  test "reload!/0 sends recompilation through GenServer" do
    assert Phoenix.CodeReloader.reload! == :noop
  end
end
