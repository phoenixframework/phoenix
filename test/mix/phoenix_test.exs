defmodule Mix.PhoenixTest do
  use ExUnit.Case, async: true

  doctest Mix.Phoenix, import: true

  test "base/0 returns the module base based on the Mix application" do
    assert Mix.Phoenix.base() == "Phoenix"
    Application.put_env(:phoenix, :namespace, Phoenix.Sample.App)
    assert Mix.Phoenix.base() == "Phoenix.Sample.App"
  after
    Application.delete_env(:phoenix, :namespace)
  end

  test "modules/0 returns all modules in project" do
    assert Phoenix.Router in Mix.Phoenix.modules()
  end

  describe "indent_text/2" do
    test "indents text with spaces, and gaps (empty lines) on top and bottom" do
      text = """

        def unique_post_price do
          raise "implement the logic to generate a unique post price"
        end

        def unique_post_published_at do
          raise "implement the logic to generate a unique post published_at"
        end


      """

      assert Mix.Phoenix.indent_text(text, spaces: 4, bottom: 1) ==
               """
                     def unique_post_price do
                       raise "implement the logic to generate a unique post price"
                     end

                     def unique_post_published_at do
                       raise "implement the logic to generate a unique post published_at"
                     end
               """
    end

    test "joins lines into indented text with spaces, and gaps (empty lines) on top and bottom" do
      lines = [
        "line number 1",
        "",
        "",
        "line number 4"
      ]

      assert Mix.Phoenix.indent_text(lines, spaces: 2, top: 2, bottom: 2) ==
               """


                 line number 1


                 line number 4

               """
    end

    test "joins lines with given option" do
      lines = [
        "first: :ready",
        "second: :steady",
        "third: :go!"
      ]

      assert Mix.Phoenix.indent_text(lines, spaces: 6, top: 1, new_line: ",\n") ==
               """

                     first: :ready,
                     second: :steady,
                     third: :go!
               """
               |> String.trim_trailing("\n")
    end
  end
end
