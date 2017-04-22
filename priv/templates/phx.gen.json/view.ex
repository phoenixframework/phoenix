defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>View do
  use <%= inspect context.web_module %>, :view
  alias <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>View

  def render("index.json", %{<%= schema.plural %>: <%= schema.plural %>}) do
    %{data: render_many(<%= schema.plural %>, <%= inspect schema.alias %>View, "<%= schema.singular %>.json")}
  end

  def render("show.json", %{<%= schema.singular %>: <%= schema.singular %>}) do
    %{data: render_one(<%= schema.singular %>, <%= inspect schema.alias %>View, "<%= schema.singular %>.json")}
  end

  def render("<%= schema.singular %>.json", %{<%= schema.singular %>: <%= schema.singular %>}) do
    %{id: <%= schema.singular %>.id<%= for {k, _} <- schema.attrs do %>,
      <%= k %>: <%= schema.singular %>.<%= k %><% end %>}
  end
end
