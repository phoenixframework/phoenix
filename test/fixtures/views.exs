import Phoenix.HTML

defmodule MyApp.View do
  use Phoenix.View, root: "test/fixtures/templates"

  def escaped_title(title) do
    html_escape title
  end
end

defmodule MyApp.LayoutView do
  use Phoenix.View, root: "test/fixtures/templates"

  def default_title do
    "MyApp"
  end
end

defmodule MyApp.UserView do
  use Phoenix.View, root: "test/fixtures/templates"

  def escaped_title(title) do
    html_escape title
  end

  def render("edit.html", %{} = assigns) do
    "EDIT#{assigns[:layout]} - #{assigns[:title]}"
  end
end

defmodule MyApp.Templates.UserView do
  use Phoenix.View, root: "test/fixtures"

  def escaped_title(title) do
    html_escape title
  end
end

defmodule MyApp.Nested.UserView do
  use Phoenix.View, root: "test/fixtures/templates", namespace: MyApp.Nested

  def escaped_title(title) do
    html_escape title
  end
end
