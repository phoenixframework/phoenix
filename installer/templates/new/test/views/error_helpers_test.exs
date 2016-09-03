defmodule <%= application_module %>.ErrorHelpersTest do
  use ExUnit.Case, async: true

  alias <%= application_module %>.ErrorHelpers

<%= if html do %>
  describe ".error_tag/3" do
    setup do
      form = %Phoenix.HTML.Form{errors: [title: {"some error message", []}]}
      %{form: form}
    end

    test "renders an error tag with default class name", %{form: form} do
      {:safe, escaped} = ErrorHelpers.error_tag(form, :title)
      assert Enum.join(escaped) =~ "class=\"help-block\""
    end

    test "renders an error tag with defined class name", %{form: form} do
      {:safe, escaped} = ErrorHelpers.error_tag(form, :title, class: "some-class")
      assert Enum.join(escaped) =~ "class=\"some-class\""
    end
  end
<% end %>
end

