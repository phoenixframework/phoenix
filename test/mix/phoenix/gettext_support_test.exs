defmodule Mix.Phoenix.GettextSupportTest do
  use ExUnit.Case, async: true

  doctest Mix.Phoenix.GettextSupport, import: true

  test "gettext_support.ex in sync with installer" do
    in_phoenix = read_split!("lib/mix/phoenix/gettext_support.ex")
    in_installer = read_split!("installer/lib/phx_new/gettext_support.ex")

    assert in_phoenix.first_line == "defmodule Mix.Phoenix.GettextSupport do"
    assert in_installer.first_line == "defmodule Phx.New.GettextSupport do"
    assert in_phoenix.rest == in_installer.rest
    assert in_phoenix.rest =~ "gettext("
  end

  defp read_split!(path) do
    File.read!(path)
    |> String.split("\n", parts: 2)
    |> then(fn [first_line, rest] -> %{first_line: first_line, rest: rest} end)
  end
end
