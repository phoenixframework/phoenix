defmodule DefaultAppWeb.CoreComponentsTest do
  import Phoenix.LiveViewTest
  import DefaultAppWeb.CoreComponents

  use Phoenix.Component
  use DefaultAppWeb.ConnCase

  describe "label component" do
    test "generates a label" do
      assigns = %{}

      html = rendered_to_string(~H"""
        <.input type="checkbox" name="example" label="Click here"/>
      """)

      assert html =~ "Click here"
    end
  end
end
