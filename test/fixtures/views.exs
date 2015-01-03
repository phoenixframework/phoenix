defmodule MyApp.View do
  use Phoenix.View, root: "test/fixtures/templates"

  using do
    quote do
      use Phoenix.HTML
    end
  end

  def escaped_title(title) do
    safe html_escape title
  end
end

defmodule MyApp.LayoutView do
  use MyApp.View

  def default_title do
    "MyApp"
  end
end

defmodule MyApp.UserView do
  use MyApp.View

  def render("edit.html", %{} = assigns) do
    "EDIT#{assigns[:layout]} - #{assigns[:title]}"
  end
end

defmodule MyApp.Templates.UserView do
  use MyApp.View, root: "test/fixtures"
end

defmodule MyApp.Nested.UserView do
  use Phoenix.View, root: "test/fixtures/templates", namespace: MyApp.Nested
  use Phoenix.HTML

  def escaped_title(title) do
    safe html_escape title
  end
end
