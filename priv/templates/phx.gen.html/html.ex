defmodule <%= inspect context.web_module %>.<%= inspect Module.concat(schema.web_namespace, schema.alias) %>HTML do
  use <%= inspect context.web_module %>, :html

  embed_templates "<%= schema.singular %>_html/*"

  @doc """
  Renders a <%= schema.singular %> form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def <%= schema.singular %>_form(assigns)
end
