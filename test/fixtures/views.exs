defmodule MyApp.View do
  use Phoenix.View, root: "test/fixtures/templates"

  def escaped_title(title) do
    {:safe, Plug.HTML.html_escape(title)}
  end
end

defmodule MyApp.LayoutView do
  use Phoenix.View, root: "test/fixtures/templates"

  def default_title do
    "MyApp"
  end
end

defmodule MyApp.User do
  defstruct name: "name"
end

defmodule MyApp.UserView do
  use Phoenix.View, root: "test/fixtures/templates"

  def escaped_title(title) do
    {:safe, Plug.HTML.html_escape(title)}
  end

  def render("show.text", %{user: user, prefix: prefix}) do
    "show user: " <> prefix <> user.name
  end

  def render("show.text", %{user: user}) do
    "show user: " <> user.name
  end

  def render("data.text", %{data: data}) do
    "show data: " <> data.name
  end

  def render("edit.html", %{} = assigns) do
    "EDIT#{assigns[:layout]} - #{assigns[:title]}"
  end

  def render("existing.html", _), do: "rendered existing"

  def render("inner.html", assigns) do
    """
    View module is #{assigns.view_module} and view template is #{assigns.view_template}
    """
  end

  def render("render_template.html" = tpl, %{name: name}) do
    render_template(tpl, %{name: String.upcase(name)})
  end
end

defmodule MyApp.Templates.UserView do
  use Phoenix.View, root: "test/fixtures"

  def escaped_title(title) do
    {:safe, Plug.HTML.html_escape(title)}
  end
end

defmodule MyApp.Nested.User do
  defstruct name: "nested name"
end

defmodule MyApp.Nested.UserView do
  use Phoenix.View, root: "test/fixtures/templates", namespace: MyApp.Nested

  def render("show.text", %{user: user}) do
    "show nested user: " <> user.name
  end

  def escaped_title(title) do
    {:safe, Plug.HTML.html_escape(title)}
  end
end
